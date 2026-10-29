#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "Usage: $0 [debug|release] [--stage] [--notarize]"; }
configuration=debug
stage=false
notarize=false
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then configuration="$1"; shift; fi
case "$configuration" in debug|release) ;; *) usage >&2; exit 2 ;; esac
for option in "$@"; do
    case "$option" in
        --stage) stage=true ;;
        --notarize) notarize=true; stage=true ;;
        --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
source scripts/lib/build-signing.sh
prepare_signing "$configuration" "${PILOT_SIGNING_IDENTITY:--}" "$notarize"
app_name=YourDotMiniAuthPilot
if [ "$stage" = false ]; then
    process_status=0
    /usr/bin/pgrep -x "$app_name" >/dev/null || process_status=$?
    if [ "$process_status" -eq 0 ]; then
        echo "Quit Completely before rebuilding, or use --stage. Keep the same bundle for persistence trials." >&2
        exit 1
    fi
    if [ "$process_status" -gt 1 ]; then
        echo "Cannot verify whether the pilot is running. Run this script from a normal terminal." >&2
        exit 1
    fi
fi

# Keep compiler caches in the workspace. --disable-sandbox only affects SwiftPM's
# build process; the resulting .app is always signed with App Sandbox enabled.
mkdir -p .build/tmp .build/clang-cache .build/swift-cache build
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
# Native SwiftPM also works on Command Line Tools-only installations.
swift_args=(--disable-sandbox --build-system native --cache-path "$PWD/.build/cache" \
    --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
swift build "${swift_args[@]}" -c "$configuration" --product "$app_name"
bin_path="$(swift build "${swift_args[@]}" -c "$configuration" --show-bin-path)"
output_path="$PWD/build"
if [ "$stage" = true ]; then
    output_path="$(mktemp -d "$PWD/build/staged.XXXXXX")"
fi
app_path="$output_path/$app_name.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/$app_name" "$app_path/Contents/MacOS/$app_name"
cp Resources/Info.plist "$app_path/Contents/Info.plist"

# Use the same signing identity throughout a persistence trial.
codesign --force --sign "$signing_identity" "$signing_timestamp" \
    --options runtime --entitlements Resources/AuthPilot.entitlements "$app_path"
codesign --verify --strict "$app_path"
{
    date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'
    echo "Configuration: $configuration"
    echo "Bundle identifier: local.YourDotMini.AuthPilot"
    echo "Signing identity: $signing_identity"
    swift --version
    sw_vers
    shasum -a 256 "$app_path/Contents/MacOS/$app_name"
} > "$output_path/BUILD_INFO.txt"
if [ "$notarize" = true ]; then
    notarize_app "$app_path"
    echo "Notarization: Accepted; stapled and validated" >> "$output_path/BUILD_INFO.txt"
fi
echo "Built: $app_path"
echo "Launch: open \"$app_path\""
