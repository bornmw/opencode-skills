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
- GitHub token with `repo` scope ([generate one](https://github.com/settings/tokens))

## Token setup

The skill reads the token from `~/.config/github-rest/token`:

```bash
echo "github_pat_..." > ~/.config/github-rest/token
chmod 600 ~/.config/github-rest/token
```

Lines starting with `#` are ignored. The first non-comment line is the token.

## Usage in opencode

Once installed, mention GitHub (PRs, issues, repos, etc.) in your opencode prompt and the skill loads automatically. Examples:

- "list open PRs in this repo"
- "show me issue #42 from anomalyco/opencode"
- "create a PR with title 'Fix bug' from branch fix to main"
- "merge PR #100 in owner/repo with squash"
- "list my issues"
- "commit and push" ← loads, because the push to a GitHub remote needs the skill's token path
- "push failed with 'could not read Username for https://github.com'" ← loads, don't make the user push by hand
