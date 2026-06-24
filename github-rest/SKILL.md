---
name: github-rest
description: |
  CRITICAL: If the user prompt contains ANY github.com URL, you MUST load this skill FIRST.
  Do NOT use Tavily, fetch, or any web-search MCP servers to read GitHub links.
  Use when the user mentions GitHub, GH, pull request(s), PR(s), issue(s),
  GitHub API, REST API, review, comment, merge, or a GitHub repo (owner/repo).
  Load when the user wants to create/view/update/merge PRs, list/create comments,
  manage issues, review code, or interact with any GitHub REST endpoint.
  Do NOT load for git in general, local git operations, or non-GitHub git hosting.
---

# GitHub REST API Skill

Calls the GitHub REST API directly with `curl` and `jq`. No wrapper script.

## Token

Read from `~/.config/github-rest/token`. Lines starting with `#` are comments. The first non-comment line is the token.

```bash
TOKEN=$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; p; q' ~/.config/github-rest/token)
```

## API call pattern

```bash
curl -sS -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/{endpoint}" | jq '{filter}'
```

For POST/PATCH/DELETE, add `-X METHOD` and `-d '{json}'` with `Content-Type: application/json`.

## Helpers — extract owner/repo from git remote

When the user omits `owner/repo`, detect it from `git remote -v`:

```bash
REPO=$(git remote -v 2>/dev/null | awk '/github.com/{print $2; exit}' | sed 's|.*github.com[:\/]||; s|\.git$||')
```

## Common operations

### PRs

```bash
# List open PRs
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?state=open&per_page=10" \
  | jq -r '.[] | "#\(.number) [\(.state)] \(.title) (@\(.user.login))"'

# View PR
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}"

# Create PR
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"...","head":"branch","base":"main","body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls"

# Merge PR
curl -sS -X PUT -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"merge_method":"squash"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/merge"

# Close PR
curl -sS -X PATCH -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"state":"closed"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}"

# List PR comments
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/comments"

# Create PR review
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body":"...","event":"APPROVE|REQUEST_CHANGES|COMMENT"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/reviews"

# List changed files
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/files" \
  | jq -r '.[] | "\(.filename) (\(.status), +\(.additions)/-\(.deletions))"'
```

### Issues

```bash
# List open issues
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/issues?state=open&per_page=10"

# Create issue
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"...","body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/issues"

# Comment on issue/PR
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/issues/{number}/comments"
```

### Comments

```bash
# List issue/PR comments
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{number}/comments"
```

## Pagination

When results may span multiple pages, check the `Link` response header. Parse with:

```bash
curl -sI -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?per_page=100" \
  | grep -oP 'rel="next"'
```

If present, fetch subsequent pages by following the `&page=N` parameter.

## Error handling

On failure, the API returns a JSON body with a `message` field. Check HTTP status code with `-w "%{http_code}"` and pipe the body through `jq '.message'`.
