#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG_DIR="$ROOT_DIR/assets/svg"
GENERATED_DIR="$ROOT_DIR/assets/generated"
RESOURCE_DIR="$ROOT_DIR/Sources/MediaKeysForSpotifyV2/Resources"
ICONSET_DIR="$GENERATED_DIR/AppIcon.iconset"

ENABLED_SVG="$SVG_DIR/enabled.svg"
DISABLED_SVG="$SVG_DIR/disabled.svg"

mkdir -p "$GENERATED_DIR" "$RESOURCE_DIR/icons" "$RESOURCE_DIR/appicon"

rasterize_svg() {
  local input="$1"
  local output="$2"
  local size="$3"
  local fallback_png="$4"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if command -v qlmanage >/dev/null 2>&1; then
    if qlmanage -t -s "$size" -o "$tmp_dir" "$input" >/dev/null 2>&1; then
      local generated
      generated="$(find "$tmp_dir" -maxdepth 1 -name '*.png' | head -n 1 || true)"
      if [[ -n "$generated" && -f "$generated" ]]; then
        cp "$generated" "$output"
        rm -rf "$tmp_dir"
        return 0
      fi
    fi
  fi

  rm -rf "$tmp_dir"

  if sips -s format png "$input" --out "$output" >/dev/null 2>&1; then
    sips -z "$size" "$size" "$output" >/dev/null 2>&1 || true
    return 0
  fi

  if [[ -f "$fallback_png" ]]; then
    cp "$fallback_png" "$output"
    sips -z "$size" "$size" "$output" >/dev/null 2>&1 || true
    return 0
  fi

  return 1
}

resize_png() {
  local input="$1"
  local output="$2"
  local size="$3"
  cp "$input" "$output"
  sips -z "$size" "$size" "$output" >/dev/null
}

echo "Generating source PNGs from SVG..."
rasterize_svg "$ENABLED_SVG" "$GENERATED_DIR/enabled-master.png" 1024 "$GENERATED_DIR/enabled-master.png"
rasterize_svg "$DISABLED_SVG" "$GENERATED_DIR/disabled-master.png" 1024 "$GENERATED_DIR/disabled-master.png"

echo "Generating menu bar icons..."
resize_png "$GENERATED_DIR/enabled-master.png" "$GENERATED_DIR/menu-enabled.png" 36
resize_png "$GENERATED_DIR/disabled-master.png" "$GENERATED_DIR/menu-disabled.png" 36
cp "$GENERATED_DIR/menu-enabled.png" "$RESOURCE_DIR/icons/menu-enabled.png"
cp "$GENERATED_DIR/menu-disabled.png" "$RESOURCE_DIR/icons/menu-disabled.png"

echo "Generating AppIcon.icns..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_16x16.png" 16
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_16x16@2x.png" 32
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_32x32.png" 32
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_32x32@2x.png" 64
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_128x128.png" 128
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_128x128@2x.png" 256
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_256x256.png" 256
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_256x256@2x.png" 512
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_512x512.png" 512
resize_png "$GENERATED_DIR/enabled-master.png" "$ICONSET_DIR/icon_512x512@2x.png" 1024

iconutil -c icns "$ICONSET_DIR" -o "$GENERATED_DIR/AppIcon.icns"
cp "$GENERATED_DIR/AppIcon.icns" "$RESOURCE_DIR/appicon/AppIcon.icns"

echo "Icons generated under $GENERATED_DIR and copied into source resources."
