#!/usr/bin/env bash
set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────────────

MISSING=""
command -v screengrab &>/dev/null || MISSING="$MISSING screengrab"
command -v convert    &>/dev/null || MISSING="$MISSING imagemagick(convert, only needed for snap.sh crop mode)"

if [ -n "$MISSING" ]; then
  echo "Error: missing dependencies:$MISSING" >&2
  echo >&2
  echo "On Gentoo, install them with:" >&2
  echo "  sudo emerge kde-apps/screengrab media-gfx/imagemagick" >&2
  echo >&2
  exit 1
fi

# ── Determine install location ────────────────────────────────────────────────

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/screengrab}"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)"

# ── Install skill (SKILL.md + scripts/) ───────────────────────────────────────

mkdir -p "$SKILL_DIR"
if [ -f "$SKILL_DIR/SKILL.md" ] && ! cmp -s "$SKILL_SRC/SKILL.md" "$SKILL_DIR/SKILL.md"; then
  cp "$SKILL_DIR/SKILL.md" "$SKILL_DIR/SKILL.md.bak"
  echo "→ Existing SKILL.md differs — backed up → $SKILL_DIR/SKILL.md.bak"
fi
echo "→ Installing skill → $SKILL_DIR/SKILL.md"
cp "$SKILL_SRC/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "→ Installing scripts → $SKILL_DIR/scripts/"
mkdir -p "$SKILL_DIR/scripts"
cp "$SKILL_SRC"/scripts/snap.sh "$SKILL_DIR/scripts/snap.sh"
chmod +x "$SKILL_DIR/scripts/snap.sh"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Installed"
echo ""
echo "  Skill:  $SKILL_DIR/SKILL.md"
echo "  Scripts:$SKILL_DIR/scripts/ (snap.sh)"
echo ""
echo "  No daemon needed — only a running display (Wayland here)."
echo ""
echo "  Verify the skill works in opencode:"
echo "     opencode run \"create a screenshot of the desktop\""
echo ""
