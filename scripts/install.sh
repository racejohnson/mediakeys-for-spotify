#!/usr/bin/env bash
# Builds the release app, installs it as /Applications/MediaKeys for Spotify.app
# (replacing any older copy), and opens it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MediaKeys for Spotify"
BUILT="$ROOT/build/$APP_NAME.app"
INSTALLED="/Applications/$APP_NAME.app"

"$ROOT/scripts/build-app.sh"

pkill -x MediaKeysForSpotify && sleep 0.5 || true

echo "==> Installing"
rm -rf "$INSTALLED"
# Move rather than copy, so Spotlight and Launch Services only ever see one copy.
mv "$BUILT" "$INSTALLED"

open "$INSTALLED"
echo "==> Installed and opened $INSTALLED"
