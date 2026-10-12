#!/usr/bin/env bash
# screengrab wrapper: capture the live display, print the saved file's path.
#
#   snap.sh                 → full-screen shot, prints path (newest ~/screen*.jpg|png)
#   snap.sh x0 y0 x1 y1      → crop that rectangle out of a fresh shot, prints crop path
#   snap.sh x0 y0 x1 y1 OUT  → same, crop saved to OUT
#
set -euo pipefail

screengrab -f -n >/dev/null

SHOT=$(ls -t ~/screen*.jpg 2>/dev/null | head -1)
[ -n "$SHOT" ] || SHOT=$(ls -t ~/screen*.png 2>/dev/null | head -1)
if [ -z "$SHOT" ]; then
  echo "snap.sh: no screenshot produced — check screengrab and defDir in ~/.config/screengrab/screengrab.conf" >&2
  exit 1
fi

if [ "$#" -ge 4 ]; then
  OUT="${5:-/tmp/opencode/snap-crop.jpg}"
  [ -d "$(dirname "$OUT")" ] || mkdir -p "$(dirname "$OUT")"
  W=$(( $3 - $1 )); H=$(( $4 - $2 ))
  [ "$W" -gt 0 ] && [ "$H" -gt 0 ] || { echo "snap.sh: bad crop rect ($1 $2 $3 $4)" >&2; exit 1; }
  if command -v magick >/dev/null; then IM=(magick); else IM=(convert); fi
  "${IM[@]}" "$SHOT" -crop "${W}x${H}+$1+$2" +repage "$OUT"
  echo "$OUT"
else
  echo "$SHOT"
fi
