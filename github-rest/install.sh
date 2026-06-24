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
echo "→ Installing skill → $SKILL_DIR/SKILL.md"
cp "$SKILL_SRC" "$SKILL_DIR/SKILL.md"

# ── Config file ───────────────────────────────────────────────────────────────

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

TOKEN_FILE="$CONFIG_DIR/token"
if [ ! -f "$TOKEN_FILE" ]; then
  cat > "$TOKEN_FILE" << 'TOKENSAMPLE'
# Replace the line below with your GitHub token (plain text, no quotes).
# Lines starting with # are ignored. The first non-comment line is the token.
# Generate one at: https://github.com/settings/tokens (repo scope)
github_pat_...
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
echo "  1. Generate a token: https://github.com/settings/tokens (repo scope)"
echo ""
echo "  2. Write the token into the config file:"
echo "       ${EDITOR:-nano} $TOKEN_FILE"
echo "     Format: one line, plain token, no quotes (# lines are ignored)"
echo ""
echo "  3. Verify the skill works in opencode:"
echo "       opencode --prompt \"list 10 most recent PRs in anomalyco/opencode using github-rest\""
echo ""
