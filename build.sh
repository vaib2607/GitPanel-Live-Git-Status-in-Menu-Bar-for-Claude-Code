#!/bin/bash
set -e

APP_NAME="GitPanel.app"
rm -rf "$APP_NAME"

echo "Building (release)..."
swift build -c release
BUILD_PATH=$(swift build -c release --show-bin-path)
EXECUTABLE="$BUILD_PATH/GitPanel"

mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp "$EXECUTABLE" "$APP_NAME/Contents/MacOS/GitPanel"
cp Resources/Info.plist "$APP_NAME/Contents/Info.plist"
cp Resources/GitPanel.entitlements "$APP_NAME/Contents/Resources/GitPanel.entitlements"
cp Resources/model_prices.json "$APP_NAME/Contents/Resources/model_prices.json"
cp Resources/GitPanel.icns "$APP_NAME/Contents/Resources/GitPanel.icns"

echo "Code signing..."
codesign --force --deep --sign - --entitlements Resources/GitPanel.entitlements "$APP_NAME" 2>/dev/null || \
  codesign --force --deep --sign - "$APP_NAME"

echo "Removing quarantine..."
xattr -d com.apple.quarantine "$APP_NAME" 2>/dev/null || true

echo "Built $APP_NAME"
echo "Run with: open $APP_NAME"
