# github-rest

An [opencode](https://opencode.ai) skill that calls the GitHub REST API directly with `curl` and `jq`. No wrapper script, no extra dependencies beyond what's already on your system.

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
