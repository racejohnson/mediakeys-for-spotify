#!/usr/bin/env bash
# Builds a debug app bundle and launches it. A real bundle (not `swift run`)
# so Accessibility and Automation grants attach to the app's bundle ID.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MediaKeys for Spotify.app"

"$ROOT/scripts/build-app.sh" --debug

# The app keeps no state that needs a graceful quit.
pkill -x MediaKeysForSpotify && sleep 0.3 || true

echo "==> Launching"
open "$APP"
