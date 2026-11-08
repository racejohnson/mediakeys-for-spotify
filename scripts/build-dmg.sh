#!/usr/bin/env bash
# Builds the release app and packages it as build/MediaKeys-for-Spotify.dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MediaKeys for Spotify"
APP="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/MediaKeys-for-Spotify.dmg"
STAGING="$ROOT/build/dmg-staging"

"$ROOT/scripts/build-app.sh"

echo "==> Staging"
trap 'rm -rf "$STAGING"' EXIT
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating disk image"
rm -f "$DMG"
if diskutil image create from --help >/dev/null 2>&1; then
  # macOS 27+: hdiutil's create verb is deprecated in favour of diskutil image.
  diskutil image create from --format UDZO --volumeName "$APP_NAME" "$STAGING" "$DMG" >/dev/null 2>&1 \
    || { echo "error: diskutil image create failed" >&2; exit 1; }
else
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
fi

echo "==> Built $DMG"
