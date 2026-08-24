#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h:h}"
WORKSPACE="$(mktemp -d)"
APP_BUNDLE="$WORKSPACE/Maclum.app"
OUTPUT_DIRECTORY="$WORKSPACE/release"

cleanup() {
  rm -rf -- "$WORKSPACE"
}
trap cleanup EXIT

mkdir -p "$APP_BUNDLE/Contents/MacOS"
touch "$APP_BUNDLE/Contents/MacOS/Maclum"
chmod +x "$APP_BUNDLE/Contents/MacOS/Maclum"
touch "$APP_BUNDLE/.DS_Store"

"$PROJECT_ROOT/scripts/package-release.sh" "$APP_BUNDLE" "$OUTPUT_DIRECTORY"

ARCHIVE="$OUTPUT_DIRECTORY/Maclum-macos-apple-silicon.zip"
CHECKSUM="$ARCHIVE.sha256"
DOWNLOAD_DIRECTORY="$WORKSPACE/download"

test -f "$ARCHIVE"
test -f "$CHECKSUM"
mkdir -p "$DOWNLOAD_DIRECTORY"
mv "$ARCHIVE" "$CHECKSUM" "$DOWNLOAD_DIRECTORY"
ARCHIVE="$DOWNLOAD_DIRECTORY/Maclum-macos-apple-silicon.zip"
CHECKSUM="$ARCHIVE.sha256"
(cd "$DOWNLOAD_DIRECTORY" && shasum -a 256 -c "$(basename "$CHECKSUM")")
unzip -Z1 "$ARCHIVE" | grep -q '^Maclum.app/Contents/MacOS/Maclum$'
if unzip -Z1 "$ARCHIVE" | grep -q '^__MACOSX/'; then
    echo "Release archive contains Finder metadata." >&2
    exit 1
fi
if unzip -Z1 "$ARCHIVE" | grep -q '/\.DS_Store$'; then
    echo "Release archive contains .DS_Store." >&2
    exit 1
fi

echo "PASS  package release"
