#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_BUNDLE="${1:-$PROJECT_ROOT/.build/app/Maclum.app}"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

if [[ ! -x "$APP_BUNDLE/Contents/MacOS/Maclum" ]]; then
  echo "Missing Maclum executable: $APP_BUNDLE" >&2
  exit 1
fi

if ! file "$APP_BUNDLE/Contents/MacOS/Maclum" | grep -q 'arm64'; then
  echo "Maclum release executable must target Apple Silicon" >&2
  exit 1
fi

if [[ ! -f "$APP_BUNDLE/Contents/Resources/Maclum.icns" ]]; then
  echo "Maclum app icon is missing" >&2
  exit 1
fi

if [[ "$(plutil -extract CFBundleIconFile raw "$INFO_PLIST")" != "Maclum.icns" ]]; then
  echo "Unexpected app icon metadata" >&2
  exit 1
fi

if [[ "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" != "dev.antonlapin.Maclum" ]]; then
  echo "Unexpected bundle identifier" >&2
  exit 1
fi

if [[ "$(plutil -extract LSUIElement raw "$INFO_PLIST")" != "true" ]]; then
  echo "Maclum must be an accessory menu-bar app" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_BUNDLE"
echo "PASS  Maclum application bundle"
