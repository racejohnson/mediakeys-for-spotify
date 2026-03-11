#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MediaKeys for Spotify V2"
EXECUTABLE_NAME="MediaKeysForSpotifyV2"
BUNDLE_ID="com.racejohnson.mediakeys-for-spotify-v2"

APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Generating icons..."
"$ROOT_DIR/scripts/generate-icons.sh"

echo "Building release binary with SwiftPM..."
swift build -c release --arch arm64 --package-path "$ROOT_DIR"

BINARY_PATH="$(find "$ROOT_DIR/.build" -type f -path "*/release/$EXECUTABLE_NAME" | head -n 1)"
if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
  echo "Unable to locate release binary for $EXECUTABLE_NAME" >&2
  exit 1
fi

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/icons"

cp "$BINARY_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/assets/generated/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/assets/generated/menu-enabled.png" "$RESOURCES_DIR/icons/menu-enabled.png"
cp "$ROOT_DIR/assets/generated/menu-disabled.png" "$RESOURCES_DIR/icons/menu-disabled.png"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>MediaKeys for Spotify V2 needs Apple Events access to control Spotify playback.</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>MediaKeys for Spotify V2 requires Accessibility permission to intercept media keys globally.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>MediaKeys for Spotify V2 requires Input Monitoring to listen for media key presses.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Applying ad-hoc signature..."
codesign --force --deep --sign - "$APP_DIR"

echo "Built app bundle:"
echo "  $APP_DIR"
