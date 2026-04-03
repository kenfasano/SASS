#!/usr/bin/env bash
# build.sh — compile SASS and assemble a .app bundle
# Usage: ./build.sh [debug|release]  (default: debug)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES_DIR="$PROJECT_DIR/SASS"
APP_NAME="SASS"
BUNDLE_ID="com.kenfasano.SASS"
VERSION="1.0"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
CONFIG="${1:-debug}"
SDK=$(xcrun --show-sdk-path)
TARGET="arm64-apple-macosx14.0"

if [[ "$CONFIG" == "release" ]]; then
    OPT_FLAGS="-O -whole-module-optimization"
else
    OPT_FLAGS="-Onone -g"
fi

echo "→ Creating bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "→ Compiling ($CONFIG)..."
swiftc \
    $OPT_FLAGS \
    -sdk "$SDK" \
    -target "$TARGET" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Foundation \
    -framework IOKit \
    -module-name "$APP_NAME" \
    "$SOURCES_DIR"/*.swift \
    -o "$BINARY"

echo "→ Binary: $BINARY ($(du -sh "$BINARY" | cut -f1))"

echo "→ Writing Info.plist..."
PLIST_PATH="$APP_BUNDLE/Contents/Info.plist"

printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>CFBundleExecutable</key>' \
'    <string>SASS</string>' \
'    <key>CFBundleIdentifier</key>' \
'    <string>com.kenfasano.SASS</string>' \
'    <key>CFBundleName</key>' \
'    <string>SASS</string>' \
'    <key>CFBundleDisplayName</key>' \
'    <string>SASS</string>' \
'    <key>CFBundleVersion</key>' \
'    <string>1.0</string>' \
'    <key>CFBundleShortVersionString</key>' \
'    <string>1.0</string>' \
'    <key>CFBundlePackageType</key>' \
'    <string>APPL</string>' \
'    <key>CFBundleDevelopmentRegion</key>' \
'    <string>en</string>' \
'    <key>LSMinimumSystemVersion</key>' \
'    <string>14.0</string>' \
'    <key>NSPrincipalClass</key>' \
'    <string>NSApplication</string>' \
'    <key>NSSupportsAutomaticTermination</key>' \
'    <false/>' \
'    <key>NSSuddenTerminationProhibited</key>' \
'    <false/>' \
'    <key>CFBundleIconFile</key>' \
'    <string>SASS</string>' \
'</dict>' \
'</plist>' \
> "$PLIST_PATH"

echo "  wrote $PLIST_PATH"

ICNS="$SOURCES_DIR/SASS.icns"
if [[ -f "$ICNS" ]]; then
    echo "→ Copying icon..."
    cp "$ICNS" "$APP_BUNDLE/Contents/Resources/SASS.icns"
else
    echo "  (no SASS.icns found in SASS/ — skipping icon)"
fi

echo "→ Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✓ Built: $APP_BUNDLE"
echo ""
echo "  Run:    open \"$APP_BUNDLE\""
echo "  Install: cp -r \"$APP_BUNDLE\" /Applications/"
