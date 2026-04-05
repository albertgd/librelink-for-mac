#!/bin/bash
set -euo pipefail

APP_NAME="LibreLinkForMac"
BUILD_DIR=".build"
RELEASE_DIR="${BUILD_DIR}/release"
APP_BUNDLE="${RELEASE_DIR}/${APP_NAME}.app"

echo "🔨 Building ${APP_NAME}..."
swift build -c release

echo "📦 Creating app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "✅ App bundle created at ${APP_BUNDLE}"
echo ""
echo "To run the app:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "To create a DMG:"
echo "  make dmg"
