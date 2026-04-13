#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Keyframe"
VERSION=$(xcodebuild -project "$PROJECT_DIR/Keyframe.xcodeproj" -scheme Keyframe -showBuildSettings 2>/dev/null | grep 'MARKETING_VERSION' | head -1 | awk '{print $3}')
VERSION=${VERSION:-"0.1.0"}

echo "Building $APP_NAME v$VERSION..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild build \
    -project "$PROJECT_DIR/Keyframe.xcodeproj" \
    -scheme Keyframe \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=NO \
    -quiet

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_PATH not found"
    exit 1
fi

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "Creating DMG..."

STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    -quiet

rm -rf "$STAGING"

echo ""
echo "Done! Distribution files:"
echo "  App:  $APP_PATH"
echo "  DMG:  $DMG_PATH"
echo ""
echo "Note: This build uses ad-hoc signing."
echo "Recipients need to right-click > Open on first launch."
echo "For proper distribution, sign with a Developer ID certificate."
