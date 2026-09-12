#!/usr/bin/env bash
# Rasterizes the readme SVGs to PNGs and JPGs for the OpenDesktop / KDE Store gallery.
#
#   readme/export_opendesktop.sh
#
# Each image keeps its SVG's basename and is rendered at 2x its native size
# (viewBox-driven, via --export-dpi) so adding or resizing an SVG needs no
# change here.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DIR/opendesktop"

perl "$DIR/generate.pl"
mkdir -p "$OUT"

for svg in "$DIR"/claude_usage.svg "$DIR"/antigravity_usage.svg "$DIR"/openai_usage.svg "$DIR"/usage_chart.svg "$DIR"/claude_pill.svg "$DIR"/agy_pill.svg "$DIR"/settings.svg; do
  [ -e "$svg" ] || continue
  name="$(basename "$svg" .svg)"
  inkscape "$svg" --export-type=png --export-filename="$OUT/$name.png" --export-dpi=192
  if command -v magick >/dev/null 2>&1; then
    magick "$OUT/$name.png" -quality 92 "$OUT/$name.jpg"
  elif command -v convert >/dev/null 2>&1; then
    convert "$OUT/$name.png" -quality 92 "$OUT/$name.jpg"
  fi
done

ls -la "$OUT"
