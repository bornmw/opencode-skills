# github-rest

A bash CLI wrapping the GitHub REST API with `curl` and `jq`. No other dependencies.

## Quick install

```bash
bash github-rest/install.sh
```

This copies `github-rest` to `~/.local/bin/` and registers the skill with opencode.

## Prerequisites

- `curl` and `jq` installed
- GitHub token with `repo` scope ([generate one](https://github.com/settings/tokens))
- Environment variable in `~/.bashrc` / `~/.zshrc`:

```bash
export GITHUB_TOKEN="github_pat_..."
```

## Usage

### Raw API

```bash
github-rest get /repos/owner/repo/pulls
github-rest post /repos/owner/repo/pulls '{"title":"My PR","head":"feature","base":"main"}'
github-rest patch /repos/owner/repo/pulls/42 '{"title":"Updated"}'
github-rest delete /repos/owner/repo/pulls/42
```

### Pull requests

```bash
github-rest pr list                                 # auto-detects owner/repo
github-rest pr view owner/repo 42
github-rest pr create --title "Fix" --head feat --base main
github-rest pr merge owner/repo 42 --method squash
github-rest pr comment owner/repo 42 "LGTM!"
github-rest pr review owner/repo 42 --body "Looks good" --event APPROVE
github-rest pr close owner/repo 42
github-rest pr files owner/repo 42
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

## Repo auto-detection

Omitting `owner/repo` reads from `git remote -v`. Run commands from inside any cloned repo:

```bash
cd ~/projects/my-repo
github-rest pr list       # works without owner/repo
```

## All commands

| Group | Subcommands |
|---|---|
| **Raw** | `get`, `post`, `patch`, `delete` |
| **PR** | `list`, `view`, `create`, `update`, `merge`, `close`, `comment`, `review`, `reviews`, `files`, `commits` |
| **Issue** | `list`, `view`, `create`, `update`, `close`, `comment` |
| **Comment** | `list`, `create` |
