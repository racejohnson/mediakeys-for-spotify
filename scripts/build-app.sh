#!/usr/bin/env bash
# Builds "build/MediaKeys for Spotify.app".
#   scripts/build-app.sh           universal (arm64 + x86_64) release build
#   scripts/build-app.sh --debug   native-arch debug build
# Signs with the first Developer ID Application or Apple Development identity in the keychain,
# else ad-hoc. Set SIGN_IDENTITY to choose one ("-" forces ad-hoc).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGING="$ROOT/Packaging"
EXECUTABLE="MediaKeysForSpotify"
APP="$ROOT/build/MediaKeys for Spotify.app"

# A real identity gives a designated requirement that survives rebuilds, so macOS keeps the
# Accessibility grant. Ad-hoc builds are identified by hash and lose it on every rebuild.
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  SIGN_IDENTITY="$( { grep -o '"Developer ID Application: [^"]*"' <<<"$IDENTITIES" \
    || grep -o '"Apple Development: [^"]*"' <<<"$IDENTITIES" || true; } | head -1 | tr -d '"')"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi

case "${1:-}" in
  "")      BUILD_ARGS=(-c release --arch arm64 --arch x86_64) ;;
  --debug) BUILD_ARGS=(-c debug) ;;
  *)       echo "usage: $(basename "$0") [--debug]" >&2; exit 64 ;;
esac

if [[ ! -d "$PACKAGING/AppIcon.icon" ]]; then
  echo "error: missing $PACKAGING/AppIcon.icon (the Icon Composer app icon)" >&2
  exit 1
fi

# SwiftPM records the deployment target as the binary's SDK version, which makes macOS
# run the app in compatibility mode (old-style controls). Record the real SDK instead.
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PACKAGING/Info.plist")"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
BUILD_ARGS+=(-Xlinker -platform_version -Xlinker macos -Xlinker "$MIN_MACOS" -Xlinker "$SDK_VERSION")

echo "==> Compiling ($([[ ${1:-} == --debug ]] && echo debug || echo 'release, universal'))"
swift build --package-path "$ROOT" "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build --package-path "$ROOT" "${BUILD_ARGS[@]}" --show-bin-path)"
BINARY="$BIN_DIR/$EXECUTABLE"
[[ -x "$BINARY" ]] || { echo "error: no executable at $BINARY" >&2; exit 1; }

echo "==> Assembling bundle"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
cp "$PACKAGING/Info.plist" "$APP/Contents/Info.plist"

echo "==> Compiling app icon"
xcrun actool "$PACKAGING/AppIcon.icon" \
  --compile "$APP/Contents/Resources" \
  --app-icon AppIcon \
  --enable-on-demand-resources NO \
  --development-region en \
  --target-device mac \
  --platform macosx \
  --minimum-deployment-target "$MIN_MACOS" \
  --output-partial-info-plist "$TMP/partial.plist" >/dev/null

echo "==> Signing (identity: $SIGN_IDENTITY)"
SIGN_ARGS=(--force --options runtime --entitlements "$PACKAGING/MediaKeysForSpotify.entitlements" --sign "$SIGN_IDENTITY")
# Notarization needs a secure timestamp; only Developer ID builds get notarized.
if [[ "$SIGN_IDENTITY" == "Developer ID Application:"* ]]; then SIGN_ARGS+=(--timestamp); fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "==> Built $APP (version $VERSION)"
