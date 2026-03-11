#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MediaKeys for Spotify V2"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"
DMG_PATH="$ROOT_DIR/build/MediaKeys-for-Spotify-V2.dmg"

echo "Building app bundle..."
"$ROOT_DIR/scripts/build-app.sh"

echo "Preparing DMG staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "Built DMG:"
echo "  $DMG_PATH"
