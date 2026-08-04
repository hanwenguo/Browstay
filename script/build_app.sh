#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-}"
APP_NAME="Browstay"
APP_PATH="$ROOT/build/$APP_NAME.app"

swift_args=(build -c "$CONFIGURATION" --package-path "$ROOT")
if [[ -n "$ARCHS" ]]; then
  for arch in $ARCHS; do
    swift_args+=(--arch "$arch")
  done
fi

swift "${swift_args[@]}" >&2
BIN_PATH="$(swift "${swift_args[@]}" --show-bin-path)"
BINARY_PATH="$BIN_PATH/$APP_NAME"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

codesign --force --sign - --options runtime --entitlements "$ROOT/Resources/Browstay.entitlements" "$APP_PATH" >&2

echo "$APP_PATH"
