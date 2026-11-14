# opencode-skills

Collection of [opencode](https://opencode.ai) skills.

## Skills

- [chatgpt](chatgpt/) — ask ChatGPT (chatgpt.com) for an answer through a Marionette-driven Firefox via the `firefox-mcp-marionette` MCP: login-wall detection (asks you to log in), visible-composer typing, stream-completion by text stabilization, finished-answer extraction
- [github-rest](github-rest/) — GitHub via CLI: REST API (PRs, issues, comments, reviews, raw API) **and** `git push` / `pull` / `clone` against GitHub remotes (token from `~/.config/github-rest/token`, never persisted)
- [screengrab](screengrab/) — create screenshots of the live Wayland/Wayfire display with the stock `screengrab` CLI (unattended `-f -n` capture, region cropping via `snap.sh`); no daemon
- [ydotool-gui](ydotool-gui/) — drive a Wayland/Wayfire desktop from the shell (move cursor with gain compensation, click, type, screenshot) via `ydotool` + `screengrab`, for headless GUI/decoration QA (needs the user-owned `ydotoold` daemon)

## Usage

Add this repo to your `~/.config/opencode/opencode.json`:

```json
{
  "skills": {
    "paths": ["/path/to/opencode-skills"]
  }
}
```

Or install individual skills globally (see each skill's `README.md`).
