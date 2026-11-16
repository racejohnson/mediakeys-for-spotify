#!/usr/bin/env bash
# Redraws docs/panel.png, the README's picture of the panel, from made-up state:
# a debug build draws it off screen, so it comes out the same on any Mac and
# nothing real is read or changed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MediaKeys for Spotify.app"

"$ROOT/scripts/build-app.sh" --debug

echo "==> Drawing"
"$APP/Contents/MacOS/MediaKeysForSpotify" --readme "$ROOT/docs"
echo "==> Wrote $ROOT/docs/panel.png"
