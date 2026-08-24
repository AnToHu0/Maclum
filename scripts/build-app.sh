#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
cd "$PROJECT_ROOT"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_ROOT="$PROJECT_ROOT/.build"
MODULE_CACHE="$BUILD_ROOT/cache/swiftpm"
CLANG_CACHE="$BUILD_ROOT/cache/clang"
mkdir -p "$BUILD_ROOT"
STAGING_ROOT="$(mktemp -d "$BUILD_ROOT/maclum-staging.XXXXXX")"
APP_BUNDLE="$STAGING_ROOT/Maclum.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
OUTPUT_ROOT="$BUILD_ROOT/app"
FINAL_APP_BUNDLE="$OUTPUT_ROOT/Maclum.app"
ICON_SOURCE="$PROJECT_ROOT/Resources/Brand/Maclum.icns"
VERSION="${MACLUM_VERSION:-1.0.0}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${MACLUM_BUILD_NUMBER:-1}"

cleanup() {
  rm -rf -- "$STAGING_ROOT"
}
trap cleanup EXIT

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Full Xcode is required. Expected: $DEVELOPER_DIR" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Maclum icon is missing: $ICON_SOURCE" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "MACLUM_VERSION must be a numeric version: $VERSION" >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "MACLUM_BUILD_NUMBER must be numeric: $BUILD_NUMBER" >&2
  exit 1
fi

mkdir -p "$MODULE_CACHE" "$CLANG_CACHE" "$MACOS" "$RESOURCES"
DEVELOPER_DIR="$DEVELOPER_DIR" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE" \
xcrun swift build -c release --product Maclum -j 1

cp "$BUILD_ROOT/arm64-apple-macosx/release/Maclum" "$MACOS/Maclum"
chmod +x "$MACOS/Maclum"
cp "$ICON_SOURCE" "$RESOURCES/Maclum.icns"

plutil -create xml1 "$CONTENTS/Info.plist"
plutil -insert CFBundleDisplayName -string "Maclum" "$CONTENTS/Info.plist"
plutil -insert CFBundleExecutable -string "Maclum" "$CONTENTS/Info.plist"
plutil -insert CFBundleIdentifier -string "dev.antonlapin.Maclum" "$CONTENTS/Info.plist"
plutil -insert CFBundleIconFile -string "Maclum.icns" "$CONTENTS/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$CONTENTS/Info.plist"
plutil -insert CFBundleName -string "Maclum" "$CONTENTS/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$CONTENTS/Info.plist"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$CONTENTS/Info.plist"
plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist"
plutil -insert LSMinimumSystemVersion -string "15.0" "$CONTENTS/Info.plist"
plutil -insert LSMultipleInstancesProhibited -bool true "$CONTENTS/Info.plist"
plutil -insert LSUIElement -bool true "$CONTENTS/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS/Info.plist"

codesign --force --deep --sign - "$APP_BUNDLE"
mkdir -p "$OUTPUT_ROOT"
rm -rf -- "$FINAL_APP_BUNDLE"
mv "$APP_BUNDLE" "$FINAL_APP_BUNDLE"
echo "$FINAL_APP_BUNDLE"
