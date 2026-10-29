#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/tmp .build/clang-cache .build/swift-cache build
export TMPDIR="$PWD/.build/tmp"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
swift_args=(--disable-sandbox --build-system native --cache-path "$PWD/.build/cache" \
    --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
swift build "${swift_args[@]}" --product WindowFocusChecks -Xswiftc -enable-testing -Xswiftc -warnings-as-errors
bin_path="$(swift build "${swift_args[@]}" --show-bin-path)"
"$bin_path/WindowFocusChecks" "$@"
