#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Balanced Spaces"
EXECUTABLE="BalancedSpaces"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release

echo "==> Assembling $APP_PATH"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp ".build/release/$EXECUTABLE" "$APP_PATH/Contents/MacOS/$EXECUTABLE"
cp Info.plist "$APP_PATH/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

echo "==> Ad-hoc signing…"
codesign --force --sign - "$APP_PATH"

echo "==> Launching…"
open "$APP_PATH"
echo "Done. Running: $APP_PATH"
