#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-debug}"
case "$configuration" in debug|release) ;; *) echo "Usage: $0 [debug|release] [--stage]" >&2; exit 2 ;; esac
case "${2:-}" in ""|--stage) ;; *) echo "Usage: $0 [debug|release] [--stage]" >&2; exit 2 ;; esac
if [ "$#" -gt 2 ]; then echo "Too many arguments." >&2; exit 2; fi
if [ "${2:-}" != --stage ]; then
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
if [ "${2:-}" = --stage ]; then
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
codesign --force --sign "${DOT_SIGNING_IDENTITY:--}" --timestamp=none --options runtime \
    --entitlements Resources/YourDotMini/YourDotMini.entitlements "$app_path"
codesign --verify --strict "$app_path"
{
    date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'
    echo "Configuration: $configuration"
    echo "Bundle identifier: local.YourDotMini"
    echo "Signing identity: ${DOT_SIGNING_IDENTITY:--}"
    swift --version
    sw_vers
    shasum -a 256 "$app_path/Contents/MacOS/YourDotMini"
} > "$output_path/APP_BUILD_INFO.txt"
echo "Built: $app_path"
