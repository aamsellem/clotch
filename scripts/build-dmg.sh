#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Clotch"
DMG_NAME="Clotch"
VERSION=$(grep MARKETING_VERSION "$PROJECT_DIR/project.yml" | head -1 | awk -F'"' '{print $2}')

echo "=== Building $APP_NAME v$VERSION ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Regenerate Xcode project
cd "$PROJECT_DIR"
xcodegen generate 2>/dev/null || true

# Build Release
echo "Building Release..."
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build 2>&1 | grep -E "(error:|warning:.*$APP_NAME|BUILD)" || true

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_PATH not found"
    exit 1
fi

echo "Build succeeded: $APP_PATH"

# Create DMG
echo "Creating DMG..."
DMG_TEMP="$BUILD_DIR/${DMG_NAME}-temp.dmg"
DMG_FINAL="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"

# Create a symlink to /Applications
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
hdiutil create \
    -volname "$DMG_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDBZ \
    "$DMG_FINAL" 2>/dev/null

rm -rf "$DMG_STAGING" "$DMG_TEMP"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_FINAL"
echo "Size: $(du -h "$DMG_FINAL" | cut -f1)"
