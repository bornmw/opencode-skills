#!/usr/bin/env bash
set -euo pipefail

# ── Dependency check ──────────────────────────────────────────────────────────

MISSING=""
command -v curl &>/dev/null || MISSING="$MISSING curl"
command -v jq   &>/dev/null || MISSING="$MISSING jq"

if [ -n "$MISSING" ]; then
  echo "Error: missing dependencies:$MISSING" >&2
  echo >&2
  echo "Install them with your package manager:" >&2
  if command -v apt &>/dev/null; then
    echo "  sudo apt install$MISSING"
  elif command -v brew &>/dev/null; then
    echo "  brew install$MISSING"
  elif command -v pacman &>/dev/null; then
    echo "  sudo pacman -S$MISSING"
  elif command -v dnf &>/dev/null; then
    echo "  sudo dnf install$MISSING"
  elif command -v yum &>/dev/null; then
    echo "  sudo yum install$MISSING"
  else
    echo "  Please install$MISSING using your package manager"
  fi
  exit 1
fi

# ── Determine install locations ──────────────────────────────────────────────

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/github-rest}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/github-rest}"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/SKILL.md"

# ── Install skill ─────────────────────────────────────────────────────────────

mkdir -p "$SKILL_DIR"
if [ -f "$SKILL_DIR/SKILL.md" ] && ! cmp -s "$SKILL_SRC" "$SKILL_DIR/SKILL.md"; then
  cp "$SKILL_DIR/SKILL.md" "$SKILL_DIR/SKILL.md.bak"
  echo "→ Existing SKILL.md differs — backed up → $SKILL_DIR/SKILL.md.bak"
fi
echo "→ Installing skill → $SKILL_DIR/SKILL.md"
cp "$SKILL_SRC" "$SKILL_DIR/SKILL.md"

# ── Config file ───────────────────────────────────────────────────────────────

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

TOKEN_FILE="$CONFIG_DIR/token"
if [ ! -f "$TOKEN_FILE" ]; then
  cat > "$TOKEN_FILE" << 'TOKENSAMPLE'
REPLACE_WITH_YOUR_GITHUB_TOKEN
TOKENSAMPLE
  chmod 600 "$TOKEN_FILE"
  echo "→ Created config: $TOKEN_FILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Installed"
echo ""
echo "  Skill:  $SKILL_DIR/SKILL.md"
echo "  Config: $TOKEN_FILE"
echo ""
echo "  Next steps:"
echo "  1. Generate a token (fine-grained PAT scoped to the repos you need — see README; fallback: https://github.com/settings/tokens)"
echo ""
echo "  2. Write the token into the config file (see README for a no-argv way to do it):"
echo "       ${EDITOR:-nano} $TOKEN_FILE"
echo "     Format: exactly one line — the token itself (no comments, no other lines)"
echo ""
echo "  3. Verify the skill works in opencode:"
echo "       opencode run \"list 10 most recent PRs in anomalyco/opencode using github-rest\""
echo ""
