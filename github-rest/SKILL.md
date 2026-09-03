---
name: github-rest
description: |
  GitHub operations: REST API AND plain `git` on github.com remotes (push, pull,
  fetch, clone, tags, branches, releases).
  CRITICAL: load this skill FIRST when the prompt contains a github.com URL, when a
  repo's `git remote` points at github.com, or when any git operation on such a remote
  is requested — and never read GitHub content via Tavily, webfetch, or any
  web-search MCP server.
  Load for: ANY `git push` (especially one that fails with "fatal: could not read
  Username for 'https://github.com'" — use this skill's token instead of asking the
  user to push from their own terminal), pull/fetch/clone/branch/tag on a GitHub
  remote, "commit and push", PRs/reviews/merges, issues, comments, or any GitHub
  REST API call.
  Do NOT load only for purely local git (status, log, diff, commit) with no GitHub
  remote, or for non-GitHub hosts (GitLab, Bitbucket, Gitea, self-hosted).
---

# GitHub REST API Skill

GitHub REST API via `curl` and `jq`, plus plain `git` operations against GitHub remotes. No wrapper script.

## When to load

- Prompt contains a `github.com` URL, or the repo's `git remote` is on GitHub.
- `git push` / `pull` / `fetch` / `clone` / branches / tags / releases on a GitHub remote — **including the first `git push` after a local commit** (you cannot push without knowing this skill's credential mechanism), and any credential/prompt failure.
- PRs, reviews, merges, issues, comments, or raw REST calls.
- Not needed: purely local git (status, log, diff, commit) with no GitHub remote; GitLab/Bitbucket/Gitea/self-hosted remotes.

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

## Git operations (push / pull / fetch / clone)

The token also authenticates plain `git` over HTTPS (needs classic `repo` scope, or a fine-grained token with `Contents: Read and write`). This is the canonical push path in headless environments: no `gh`, no GUI credential helper, no keychain.

**Rule: the token must never persist.** Per-command ephemeral `x-access-token` URL, token in an environment variable, unset afterwards, `git -c credential.helper=` so nothing is cached. Never write the token into `origin`, `.git/config`, or `~/.git-credentials`.

```bash
TOKEN=$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; p; q' ~/.config/github-rest/token)
REPO=$(git remote -v 2>/dev/null | awk '/github.com/{print $2; exit}' | sed 's|.*github.com[:\/]||; s|\.git$||')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_TERMINAL_PROMPT=0 git -c credential.helper= push "https://x-access-token:${TOKEN}@github.com/${REPO}.git" "$BRANCH"
unset TOKEN
```

- `git pull` / `git fetch`: swap the verb, same URL pattern. `git push --tags` the same way.
- `git clone "https://x-access-token:${TOKEN}@github.com/${REPO}.git" dir` — then **scrub immediately**: `git -C dir remote set-url origin "https://github.com/${REPO}.git"` (the clone bakes the URL into config).
- `GIT_TERMINAL_PROMPT=0` prevents hanging on a tty; `-c credential.helper=` prevents the OS helper from prompting/caching.
- **Verify after pushing**: `curl .../repos/{owner}/{repo}/branches/{branch}` → compare `commit.sha` to `git rev-parse`. `GET /commits/{branch}` can return a stale HEAD for seconds right after a push — do not treat that as a failed push.
- `fatal: could not read Username for 'https://github.com'` = the user has no git credentials in this environment. Use this section; do **not** ask them to push from their own terminal as a workaround.
- Never print `$TOKEN`; when it must be shown (e.g. in an error), mask it (`${TOKEN:0:4}…`).

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

- `401` = token missing/expired; `403` = token lacks the scope (PR writes need `repo`; git push needs `repo` or `Contents: write`). Ask the user to replace the token file — do not retry loops.
