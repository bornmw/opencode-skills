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

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/github-rest}"

SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/scripts/github-rest"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/SKILL.md"

# ── Install ───────────────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"
mkdir -p "$SKILL_DIR"

echo "→ Installing github-rest CLI → $INSTALL_DIR/github-rest"
cp "$SCRIPT_SRC" "$INSTALL_DIR/github-rest"
chmod +x "$INSTALL_DIR/github-rest"

echo "→ Installing skill definition → $SKILL_DIR/SKILL.md"
cp "$SKILL_SRC" "$SKILL_DIR/SKILL.md"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Installed"
echo ""
echo "  CLI:      $INSTALL_DIR/github-rest"
echo "  Skill:    $SKILL_DIR/SKILL.md"
echo ""
echo "  Next steps:"
echo "  1. Add to your shell profile (~/.bashrc, ~/.zshrc):"
echo "       export GITHUB_TOKEN=\"github_pat_...\""
echo "       export PATH=\"\$PATH:$INSTALL_DIR\""
echo "  2. Generate a token: https://github.com/settings/tokens"
echo "  3. Verify it works:  github-rest get /user"
echo ""
