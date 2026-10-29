#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
usage() { echo "Usage: $0 [debug|release] [--stage] [--notarize [--dmg]]"; }
configuration=debug
stage=false
notarize=false
dmg=false
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then configuration="$1"; shift; fi
case "$configuration" in debug|release) ;; *) usage >&2; exit 2 ;; esac
for option in "$@"; do
    case "$option" in
        --stage) stage=true ;;
        --notarize) notarize=true; stage=true ;;
        --dmg) dmg=true ;;
        --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [ "$dmg" = true ] && [ "$notarize" = false ]; then
    echo "--dmg requires release --notarize." >&2
    exit 2
fi
source scripts/lib/build-signing.sh
prepare_signing "$configuration" "${DOT_SIGNING_IDENTITY:--}" "$notarize"
if [ "$stage" = false ]; then
    process_status=0
    /usr/bin/pgrep -x YourDotMini >/dev/null || process_status=$?
    if [ "$process_status" -ne 1 ]; then
        echo "Quit YourDotMini before replacing it, or use --stage to prepare a separate build." >&2
        exit 1
    fi
fi
mkdir -p .build/tmp .build/clang-cache .build/swift-cache build
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift_args=(--disable-sandbox --build-system native --cache-path "$PWD/.build/cache" \
    --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
swift build "${swift_args[@]}" -c "$configuration" --product YourDotMini -Xswiftc -warnings-as-errors
bin_path="$(swift build "${swift_args[@]}" -c "$configuration" --show-bin-path)"
output_path="$PWD/build"
if [ "$stage" = true ]; then
    # A fresh directory cannot contain a running app. Never replace the installed
    # bundle or terminate a process just to prepare an update.
    output_path="$(mktemp -d "$PWD/build/staged.XXXXXX")"
fi
app_path="$output_path/YourDotMini.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/YourDotMini" "$app_path/Contents/MacOS/YourDotMini"
cp Resources/YourDotMini/Info.plist "$app_path/Contents/Info.plist"
./scripts/build-icon.sh
cp build/app-icon/compiled/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
if [ -f build/app-icon/compiled/Assets.car ]; then
    cp build/app-icon/compiled/Assets.car "$app_path/Contents/Resources/Assets.car"
else
    rm -f "$app_path/Contents/Resources/Assets.car"
fi
codesign --force --sign "$signing_identity" "$signing_timestamp" --options runtime \
    --entitlements Resources/YourDotMini/YourDotMini.entitlements "$app_path"
codesign --verify --strict "$app_path"
{
    date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'
    echo "Configuration: $configuration"
    echo "Bundle identifier: local.YourDotMini"
    echo "Signing identity: $signing_identity"
    swift --version
    sw_vers
    shasum -a 256 "$app_path/Contents/MacOS/YourDotMini"
} > "$output_path/APP_BUILD_INFO.txt"
if [ "$notarize" = true ]; then
    notarize_app "$app_path"
    echo "Notarization: Accepted; stapled and validated" >> "$output_path/APP_BUILD_INFO.txt"
    if [ "$dmg" = true ]; then
        notarize_dmg "$app_path"
        echo "Disk image notarization: Accepted; stapled and validated" >> "$output_path/APP_BUILD_INFO.txt"
    fi
fi
echo "Built: $app_path"
