---
name: github-rest
description: |
  Use ONLY when the user mentions GitHub, GH, pull request(s), PR(s), issue(s),
  GitHub API, REST API, review, comment, merge, or a GitHub repo (owner/repo).
  Load when the user wants to create/view/update/merge PRs, list/create comments,
  manage issues, review code, or interact with any GitHub REST endpoint.
  Do NOT load for git in general, local git operations, or non-GitHub git hosting.
---

# GitHub REST API Skill

This skill provides a `github-rest` CLI tool that wraps the GitHub REST API using `curl` and `jq`. It handles common workflows (PRs, issues, comments, reviews) and supports raw API access for everything else.

## Install

```bash
# From this repository:
bash github-rest/install.sh
```

This copies `github-rest` to `~/.local/bin/` and the skill definition to `~/.config/opencode/skills/github-rest/`.

## Prerequisites

- `curl` and `jq` installed
- A [GitHub personal access token](https://github.com/settings/tokens) with `repo` scope
- Environment variable `GITHUB_TOKEN` set in your shell profile

## Usage

### Raw API access — any endpoint, any method

```bash
github-rest get /repos/owner/repo/pulls
github-rest post /repos/owner/repo/pulls '{"title":"My PR","head":"feature","base":"main"}'
github-rest patch /repos/owner/repo/pulls/42 '{"title":"Updated"}'
github-rest delete /repos/owner/repo/pulls/42
```

### Pull requests

```bash
github-rest pr list                              # list open PRs (auto-detects repo)
github-rest pr view owner/repo 42                # view PR details
github-rest pr create --title "Fix" --head feat --base main   # create PR (auto repo)
github-rest pr merge owner/repo 42 --method squash
github-rest pr comment owner/repo 42 "LGTM!"
github-rest pr review owner/repo 42 --body "Looks good" --event APPROVE
github-rest pr close owner/repo 42
github-rest pr files owner/repo 42               # changed files
github-rest pr commits owner/repo 42
```

### Issues

```bash
github-rest issue list
github-rest issue view owner/repo 42
github-rest issue create --title "Bug" --body "Steps to reproduce..."
github-rest issue comment owner/repo 42 "Fixed in #43"
github-rest issue close owner/repo 42
```

### Comments

```bash
github-rest comment list owner/repo 42
github-rest comment create owner/repo 42 --body "Thanks!"
```

### Repo auto-detection

When `owner/repo` is omitted, the script reads it from `git remote -v`. This means you can run `github-rest pr list` inside any cloned GitHub repo without typing the repo name.

## Token setup

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export GITHUB_TOKEN="github_pat_..."
```

Generate a token at: https://github.com/settings/tokens (needs `repo` scope).
