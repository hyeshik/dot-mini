#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${1:-debug}"
case "$configuration" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;; esac
app_name=YourDotMiniAuthPilot
process_status=0
/usr/bin/pgrep -x "$app_name" >/dev/null || process_status=$?
if [ "$process_status" -eq 0 ]; then
    echo "Quit Completely before rebuilding. Keep the same bundle for persistence trials." >&2
    exit 1
fi
if [ "$process_status" -gt 1 ]; then
    echo "Cannot verify whether the pilot is running. Run this script from a normal terminal." >&2
    exit 1
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
app_path="$PWD/build/$app_name.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/$app_name" "$app_path/Contents/MacOS/$app_name"
cp Resources/Info.plist "$app_path/Contents/Info.plist"

# Local development only. Use the same signing identity throughout a trial.
codesign --force --sign "${PILOT_SIGNING_IDENTITY:--}" --timestamp=none \
    --options runtime --entitlements Resources/AuthPilot.entitlements "$app_path"
codesign --verify --strict "$app_path"
{
    date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'
    echo "Configuration: $configuration"
    echo "Bundle identifier: local.YourDotMini.AuthPilot"
    echo "Signing identity: ${PILOT_SIGNING_IDENTITY:--}"
    swift --version
    sw_vers
    shasum -a 256 "$app_path/Contents/MacOS/$app_name"
} > build/BUILD_INFO.txt
echo "Built: $app_path"
echo "Launch: open \"$app_path\""
