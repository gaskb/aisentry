#!/bin/bash
set -euo pipefail

APP_NAME="AiSentry"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"

VERSION=$(grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' "$ROOT_DIR/Sources/AiSentry/Version.swift" | tr -d '"')
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

"$ROOT_DIR/Scripts/build_app.sh"

echo
echo "Packaging DMG..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "Built: $DMG_PATH"
echo
echo "Not notarized: on first launch after copying to /Applications, macOS will"
echo "flag it as from an unidentified developer. To open it: right-click the app"
echo "in Applications > Open, then confirm in the dialog (only needed once)."
