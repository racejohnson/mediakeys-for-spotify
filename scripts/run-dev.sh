#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT_DIR/scripts/generate-icons.sh"
swift run --package-path "$ROOT_DIR" MediaKeysForSpotify
