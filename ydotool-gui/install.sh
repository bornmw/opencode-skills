#!/usr/bin/env bash
set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────────────

MISSING=""
command -v ydotool   &>/dev/null || MISSING="$MISSING ydotool"
command -v screengrab &>/dev/null || MISSING="$MISSING screengrab"
command -v python3   &>/dev/null || MISSING="$MISSING python3"
command -v wlr-randr &>/dev/null || MISSING="$MISSING wlr-randr"
python3 -c "import PIL" &>/dev/null || MISSING="$MISSING python3-PIL"

if [ -n "$MISSING" ]; then
  echo "Error: missing dependencies:$MISSING" >&2
  echo >&2
  echo "On Gentoo, install them with:" >&2
  echo "  sudo emerge app-misc/ydotool kde-apps/screengrab dev-python/pillow" >&2
  echo >&2
  exit 1
fi

# ── Determine install location ────────────────────────────────────────────────

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/ydotool-gui}"
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
cp "$SKILL_SRC"/scripts/ymove.sh      "$SKILL_DIR/scripts/ymove.sh"
cp "$SKILL_SRC"/scripts/find_cursor.py "$SKILL_DIR/scripts/find_cursor.py"
cp "$SKILL_SRC"/scripts/goto.sh       "$SKILL_DIR/scripts/goto.sh"
cp "$SKILL_SRC"/scripts/cursor-pos.c  "$SKILL_DIR/scripts/cursor-pos.c"
cp "$SKILL_SRC"/scripts/build-cursor-pos.sh "$SKILL_DIR/scripts/build-cursor-pos.sh"
chmod +x "$SKILL_DIR/scripts/build-cursor-pos.sh"
mkdir -p "$SKILL_DIR/scripts/protocols"
cp "$SKILL_SRC"/scripts/protocols/*.xml "$SKILL_DIR/scripts/protocols/"
chmod +x "$SKILL_DIR/scripts/"*

# ── Build cursor-pos (needs gcc + wayland-scanner) ───────────────────────────
if command -v gcc &>/dev/null && command -v wayland-scanner &>/dev/null; then
  echo "→ Building cursor-pos"
  ( cd "$SKILL_DIR/scripts" && bash build-cursor-pos.sh >/dev/null ) \
    || echo "  ! cursor-pos build failed — goto.sh will fall back to reporting"
else
  echo "  ! gcc/wayland-scanner missing — cursor-pos not built (goto.sh needs it)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Installed"
echo ""
echo "  Skill:  $SKILL_DIR/SKILL.md"
echo "  Scripts:$SKILL_DIR/scripts/ (goto.sh, cursor-pos, ymove.sh, find_cursor.py)"
echo ""
echo "  Prerequisites (see README for the full daemon setup):"
echo "  1. ydotoold running as root:  ydotoold -o <uid>:<gid> -P 0660"
echo "     (openrc: /etc/init.d/ydotool  command_args=\"-o <uid>:<gid> -P 0660\";"
echo "      do NOT use -T; then  sudo rc-update add ydotool default)"
echo "  2. Client env:  export YDOTOOL_SOCKET=/tmp/.ydotool_socket"
echo "  3. screengrab with 'Include mouse pointer' enabled"
echo ""
echo "  Verify the daemon + client:"
echo "     pgrep -a ydotoold && ls -l /tmp/.ydotool_socket"
echo "     YDOTOOL_SOCKET=/tmp/.ydotool_socket ydotool debug"
echo ""
echo "  Verify the skill works in opencode:"
echo "     opencode run \"screenshot the desktop using ydotool-gui\""
echo ""
