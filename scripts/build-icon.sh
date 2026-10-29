#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output_dir="${1:-$PWD/build/app-icon/compiled}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [ ! -x "$developer_dir/usr/bin/actool" ] && [ -x /Applications/Xcode.app/Contents/Developer/usr/bin/actool ]; then
    developer_dir=/Applications/Xcode.app/Contents/Developer
fi
if [ -x "$developer_dir/usr/bin/actool" ]; then
    DEVELOPER_DIR="$developer_dir" "$developer_dir/usr/bin/actool" \
        "$PWD/Resources/YourDotMini/AppIcon.icon" \
        --compile "$output_dir" --platform macosx --minimum-deployment-target 14.0 \
        --app-icon AppIcon --output-partial-info-plist "$output_dir/partial-info.plist" \
        --output-format human-readable-text --warnings --notices
else
    # A checked-in rendering keeps Command Line Tools-only builds usable.
    rm -f "$output_dir/Assets.car"
    cp Resources/YourDotMini/AppIcon.icns "$output_dir/AppIcon.icns"
    echo "Xcode is unavailable; using the rendered app icon."
fi
