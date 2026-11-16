#!/usr/bin/env bash
# Rewrites the app icon's note layer (Packaging/AppIcon.icon/Assets/note.svg) from the menu bar
# glyph's path, so the icon and the menu bar show the same note, then re-exports docs/icon.png.
# Run it after changing the note in MenuBarGlyph.swift or anything in Packaging/AppIcon.icon.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/MediaKeys for Spotify.app"
ICON="$ROOT/Packaging/AppIcon.icon"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

"$ROOT/scripts/build-app.sh" --debug

echo "==> Writing the note"
"$APP/Contents/MacOS/MediaKeysForSpotify" --icon-note "$ICON/Assets/note.svg"

echo "==> Exporting docs/icon.png"
"$ICTOOL" "$ICON" --export-image --output-file "$ROOT/docs/icon.png" \
  --platform macOS --rendition Default --width 512 --height 512 --scale 1 >/dev/null
[[ -s "$ROOT/docs/icon.png" ]] || { echo "error: ictool did not write docs/icon.png" >&2; exit 1; }
echo "==> Wrote $ICON/Assets/note.svg and $ROOT/docs/icon.png"
