#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
cd "$PROJECT_ROOT"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_ROOT="$PROJECT_ROOT/.build"
MODULE_CACHE="$BUILD_ROOT/cache/swiftpm"
CLANG_CACHE="$BUILD_ROOT/cache/clang"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Full Xcode is required. Expected: $DEVELOPER_DIR" >&2
  exit 1
fi

mkdir -p "$MODULE_CACHE" "$CLANG_CACHE"
DEVELOPER_DIR="$DEVELOPER_DIR" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
xcrun swift test
