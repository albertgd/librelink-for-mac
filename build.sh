#!/bin/bash
set -euo pipefail

APP_NAME="LibreLinkForMac"
BUILD_DIR=".build"
RELEASE_DIR="${BUILD_DIR}/release"
APP_BUNDLE="${RELEASE_DIR}/${APP_NAME}.app"
ICNS_FILE="AppIcon.icns"

echo "🎨 Generating app icon..."
mkdir -p AppIcon.iconset
sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png    > /dev/null
sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png    > /dev/null
sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png  > /dev/null
sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png  > /dev/null
sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png  > /dev/null
sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
iconutil -c icns AppIcon.iconset --output "${ICNS_FILE}"
rm -rf AppIcon.iconset
echo "✅ Icon generated at ${ICNS_FILE}"

echo "🔨 Building ${APP_NAME}..."
swift build -c release

echo "📦 Creating app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "${ICNS_FILE}" "${APP_BUNDLE}/Contents/Resources/${ICNS_FILE}"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

echo "✅ App bundle created at ${APP_BUNDLE}"
echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To create a DMG:"
echo "  make dmg"
