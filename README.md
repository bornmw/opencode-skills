# opencode-skills

Collection of [opencode](https://opencode.ai) skills.

## Skills

- [github-rest](github-rest/) — GitHub via CLI: REST API (PRs, issues, comments, reviews, raw API) **and** `git push` / `pull` / `clone` against GitHub remotes (token from `~/.config/github-rest/token`, never persisted)
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
