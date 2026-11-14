#!/usr/bin/env bash
set -euo pipefail

# ── Determine install location ───────────────────────────────────────────────

SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode/skills/chatgpt}"
SKILL_SRC="$(cd "$(dirname "$0")" && pwd)/SKILL.md"

# ── Install skill ────────────────────────────────────────────────────────────

mkdir -p "$SKILL_DIR"
if [ -f "$SKILL_DIR/SKILL.md" ] && ! cmp -s "$SKILL_SRC" "$SKILL_DIR/SKILL.md"; then
  cp "$SKILL_DIR/SKILL.md" "$SKILL_DIR/SKILL.md.bak"
  echo "→ Existing SKILL.md differs — backed up → $SKILL_DIR/SKILL.md.bak"
fi
echo "→ Installing skill → $SKILL_DIR/SKILL.md"
cp "$SKILL_SRC" "$SKILL_DIR/SKILL.md"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Installed"
echo ""
echo "  Skill: $SKILL_DIR/SKILL.md"
echo ""
echo "  Prerequisites:"
echo "  1. firefox-mcp-marionette MCP registered in opencode (fx_* tools available)"
echo "  2. A Firefox with an active ChatGPT login (dedicated profile recommended)"
echo ""
echo "  Verify the skill works in opencode:"
echo "    opencode run \"ask ChatGPT: what is the capital of France?\""
echo ""
