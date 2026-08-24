#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h:h}"
APP_BUNDLE="$PROJECT_ROOT/.build/app/Maclum.app"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

MACLUM_VERSION="v9.8.7" MACLUM_BUILD_NUMBER="42" "$PROJECT_ROOT/scripts/build-app.sh"

file "$APP_BUNDLE/Contents/MacOS/Maclum" | grep -q 'arm64'
test "$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")" = "9.8.7"
test "$(plutil -extract CFBundleVersion raw "$INFO_PLIST")" = "42"

echo "PASS  release app bundle"
