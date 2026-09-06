# github-rest

An [opencode](https://opencode.ai) skill for GitHub, in two parts:

1. **REST API** via `curl` and `jq` (PRs, issues, comments, reviews, raw endpoints).
2. **Plain `git` on GitHub remotes** — `push` / `pull` / `fetch` / `clone` authenticated with the same token (`x-access-token` URL, ephemeral; the token is never written to git config or a credential cache). This is the credential path in headless environments without `gh` or a GUI helper.

No wrapper script, no extra dependencies beyond what's already on your system.

## Install

```bash
bash github-rest/install.sh
```

This registers the skill at `~/.config/opencode/skills/github-rest/` and creates a config file for your token.

## Prerequisites

- `curl` and `jq` installed
- A GitHub token — **least privilege, not broad scope**:

  - Preferred: a [fine-grained PAT](https://github.com/settings/personal-access-tokens/new) restricted to the repos you actually use, with `Contents` / `Pull requests` / `Issues: read and write` (plus `Metadata` read), and a ~90-day expiry. A dedicated account beats a personal one.
  - Fallback: a classic PAT with `repo` scope ([generate one](https://github.com/settings/tokens)) — don't make this the default for this skill.

## Token setup

The skill reads the token from `~/.config/github-rest/token`. Write it without echoing it through argv/shell history:

```bash
umask 077
read -r -s -p "GitHub token: " TOKEN
printf '%s\n' "$TOKEN" > ~/.config/github-rest/token
unset TOKEN
chmod 600 ~/.config/github-rest/token
```

The file is **exactly one line: the token** (trailing newline fine; no comments, nothing else) — the skill reads it with a plain `cat`, so any extra line breaks auth.

By design the skill never materializes the value: it is never assigned to a shell variable, never written to any other file (including temp scripts), never printed, never stored in git config.

## Usage in opencode

Once installed, mention GitHub (PRs, issues, repos, etc.) in your opencode prompt and the skill loads automatically. Examples:

- "list open PRs in this repo"
- "show me issue #42 from anomalyco/opencode"
- "create a PR with title 'Fix bug' from branch fix to main"
- "merge PR #100 in owner/repo with squash"
- "list my issues"
- "commit and push" ← loads, because the push to a GitHub remote needs the skill's token path
- "push failed with 'could not read Username for https://github.com'" ← loads, don't make the user push by hand
