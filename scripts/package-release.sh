#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_NAME="Maclum"
APP_BUNDLE="${1:-$PROJECT_ROOT/.build/app/$APP_NAME.app}"
OUTPUT_DIRECTORY="${2:-$PROJECT_ROOT/.build/release}"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle is missing: $APP_BUNDLE" >&2
  echo "Run ./scripts/build-app.sh first." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIRECTORY"
ARCHIVE="$OUTPUT_DIRECTORY/$APP_NAME-macos-apple-silicon.zip"
CHECKSUM="$ARCHIVE.sha256"
STAGING_ROOT="$(mktemp -d "$OUTPUT_DIRECTORY/maclum-package.XXXXXX")"
STAGED_APP="$STAGING_ROOT/$APP_NAME.app"

cleanup() {
  rm -rf -- "$STAGING_ROOT"
}
trap cleanup EXIT

rm -f -- "$ARCHIVE" "$CHECKSUM"
ditto "$APP_BUNDLE" "$STAGED_APP"
find "$STAGED_APP" -name .DS_Store -type f -delete
ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$STAGED_APP" "$ARCHIVE"

if unzip -Z1 "$ARCHIVE" | grep -q '^__MACOSX/\|/\.DS_Store$'; then
  echo "Release archive contains Finder metadata: $ARCHIVE" >&2
  exit 1
fi

shasum -a 256 "$ARCHIVE" > "$CHECKSUM"

echo "$ARCHIVE"
echo "$CHECKSUM"
