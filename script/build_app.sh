#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_NAME="Stayfari"
APP_PATH="$ROOT/build/$APP_NAME.app"
BINARY_PATH="$ROOT/.build/$CONFIGURATION/$APP_NAME"

swift build -c "$CONFIGURATION" --package-path "$ROOT" >&2

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

codesign --force --sign - --options runtime --entitlements "$ROOT/Resources/Stayfari.entitlements" "$APP_PATH" >&2

echo "$APP_PATH"
