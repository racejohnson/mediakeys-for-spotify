#!/usr/bin/env bash
# Redraws the README's pictures in docs (panel.png and the three icon-*.png) from
# made-up state: a debug build draws them off screen, so they come out the same on
# any Mac and nothing real is read or changed. Fails, leaving the old pictures, if
# the app could not draw or write one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MediaKeys for Spotify.app"

"$ROOT/scripts/build-app.sh" --debug

echo "==> Drawing"
"$APP/Contents/MacOS/MediaKeysForSpotify" --readme "$ROOT/docs"
echo "==> Wrote panel.png, icon-on.png, icon-setup.png and icon-off.png to $ROOT/docs"
