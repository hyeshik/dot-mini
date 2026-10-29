#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tmp .build/clang-cache .build/swift-cache
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
test_args=()
developer_path="$(xcode-select -p)"
testing_frameworks="$developer_path/Library/Developer/Frameworks"
if [ -d "$testing_frameworks/Testing.framework" ]; then
    # CLT ships Swift Testing outside the SDK's default framework search path.
    test_args=(-Xswiftc -F -Xswiftc "$testing_frameworks" \
        -Xlinker -F -Xlinker "$testing_frameworks" \
        -Xlinker -rpath -Xlinker "$testing_frameworks")
fi
swift test --disable-sandbox --build-system native --cache-path "$PWD/.build/cache" \
    --config-path "$PWD/.build/config" --security-path "$PWD/.build/security" \
    --disable-xctest --enable-swift-testing "${test_args[@]}" "$@"
