# chatgpt

An [opencode](https://opencode.ai) skill that asks ChatGPT (chatgpt.com) for an
answer through a Marionette-driven Firefox, via the
[firefox-mcp-marionette](https://github.com/bornmw/firefox-mcp-marionette) MCP
(`fx_*` tools) — the user's browser, the user's profile, the user's login,
human in the loop.

The skill encodes the live-verified recipe (2026-11-14): bootstrap the
browser, detect the login wall (and ask *you* to log in — a fresh `fx_launch`
instance is always logged out), type into the **visible** composer (the DOM
contains a hidden duplicate), send via the Send button, detect end-of-stream
by text stabilization (the Stop button + two identical reads), and extract
the finished answer.

## Install

```bash
bash chatgpt/install.sh
```

This registers the skill at `~/.config/opencode/skills/chatgpt/`.

## Prerequisites

- The `marionette` MCP server registered in opencode (the `fx_*` tools are
  available) — see the firefox-mcp-marionette README for the
  `opencode.json` snippet.
- A Firefox with an active ChatGPT login (a dedicated profile is
  recommended). A fresh `fx_launch` instance starts logged out — the skill
  detects that and asks you to log in.

## Usage in opencode

Mention ChatGPT in your opencode prompt and the skill loads automatically.
Examples:

- "ask ChatGPT to review this diff"
- "get a second opinion from ChatGPT on this architecture"
- "send this prompt to ChatGPT and give me the answer"
- "check this with ChatGPT"

Not loaded for: generic browser tasks, other sites, or questions the local
model can answer without ChatGPT.
