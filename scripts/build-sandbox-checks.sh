#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tmp .build/clang-cache .build/swift-cache build
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift_args=(--disable-sandbox --build-system native --cache-path "$PWD/.build/cache" \
    --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
swift build "${swift_args[@]}" --product SandboxChecks -Xswiftc -enable-testing -Xswiftc -warnings-as-errors
bin_path="$(swift build "${swift_args[@]}" --show-bin-path)"
output_path="$(mktemp -d "$PWD/build/sandbox-checks.XXXXXX")"
make_app() {
    local name="$1" identifier="$2" app_path="$output_path/$1.app"
    mkdir -p "$app_path/Contents/MacOS"
    cp "$bin_path/SandboxChecks" "$app_path/Contents/MacOS/SandboxChecks"
    cat > "$app_path/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>$identifier</string>
    <key>CFBundleName</key><string>$name</string>
    <key>CFBundleExecutable</key><string>SandboxChecks</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF
    codesign --force --sign - --timestamp=none --options runtime \
        --entitlements Resources/YourDotMini/YourDotMini.entitlements "$app_path"
    codesign --verify --strict "$app_path"
}
make_app "YourDotMiniSandboxChecks" "local.YourDotMini.SandboxChecks"
make_app "YourDotMiniFallbackFixture" "local.YourDotMini.SandboxChecks.Target"
echo "Test app: $output_path/YourDotMiniSandboxChecks.app"
echo "Select this fixture: $output_path/YourDotMiniFallbackFixture.app"
