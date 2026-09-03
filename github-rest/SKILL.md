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

The token lives at `~/.config/github-rest/token` — the file is **exactly one line containing the token** (trailing newline fine; no comments, nothing else).

### Hard rules — the value is never materialized

- **Never assign it to a shell variable** (no `TOKEN=*** A named variable invites `echo`-ing, cross-command reuse, and accidental persistence into files.
- **Never write it to any file on disk** — no temp scripts, no logs, no /tmp artifacts. If a task needs a helper script, the script must *reference the file inline* (`$(cat ...)`), never embed the value.
- **Never print it** — not even masked. `$(cat ~/.config/github-rest/token)` appears only inside the argument of the curl/git command that consumes it — never as a standalone `cat`/`echo` of the file.
- **Never persist it** — no `git remote set-url` with credentials, no `git credential approve`, no `~/.git-credentials`.

```bash
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/{endpoint}"
```

## API call pattern

```bash
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
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

The token goes inline as `x-access-token:$(cat ~/.config/github-rest/token)` in the push URL — no variable, nothing unset-able, nothing that a second command or a written-out file can carry away.

```bash
REPO=$(git remote -v 2>/dev/null | awk '/github.com/{print $2; exit}' | sed 's|.*github.com[:\/]||; s|\.git$||')
BRANCH=$(git rev-parse --abbrev-ref HEAD)
LOCAL_SHA=$(git rev-parse HEAD)
GIT_TERMINAL_PROMPT=0 git -c credential.helper= push \
  "https://x-access-token:$(cat ~/.config/github-rest/token)@github.com/${REPO}.git" "$BRANCH"
```

- `git pull` / `git fetch`: swap the verb, same inline URL. `push --tags` the same way.
- `git clone "https://x-access-token:$(cat ~/.config/github-rest/token)@github.com/${REPO}.git" dir` — then **scrub immediately**: `git -C dir remote set-url origin "https://github.com/${REPO}.git"` (the clone bakes the expanded URL into config).
- `GIT_TERMINAL_PROMPT=0` prevents hanging on a tty; `-c credential.helper=` prevents the OS helper from prompting/caching.
- **Verify after pushing** (compare shas — `GET /commits/{branch}` can return a stale HEAD for seconds after a push and must not be read as a failed push):
  ```bash
  curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
    "https://api.github.com/repos/${REPO}/branches/${BRANCH}" | jq -r '.commit.sha'
  ```
- `fatal: could not read Username for 'https://github.com'` = the user has no git credentials in this environment. Use this section; do **not** ask them to push from their own terminal as a workaround.
- If a push ever fails with a 401, check the token *file format* instead of printing the value: `wc -l` on `~/.config/github-rest/token` (must be 1) and re-read the section header.

## Common operations

### PRs

```bash
# List open PRs
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?state=open&per_page=10" \
  | jq -r '.[] | "#\(.number) [\(.state)] \(.title) (@\(.user.login))"'

# View PR
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}"

# Create PR
curl -sS -X POST -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"title":"...","head":"branch","base":"main","body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls"

# Merge PR
curl -sS -X PUT -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"merge_method":"squash"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/merge"

# Close PR
curl -sS -X PATCH -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"state":"closed"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}"

# List PR comments
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/comments"

# Create PR review
curl -sS -X POST -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"body":"...","event":"APPROVE|REQUEST_CHANGES|COMMENT"}' \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/reviews"

# List changed files
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{number}/files" \
  | jq -r '.[] | "\(.filename) (\(.status), +\(.additions)/-\(.deletions))"'
```

### Issues

```bash
# List open issues
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/issues?state=open&per_page=10"

# Create issue
curl -sS -X POST -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"title":"...","body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/issues"

# Comment on issue/PR
curl -sS -X POST -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  -H "Content-Type: application/json" \
  -d '{"body":"..."}' \
  "https://api.github.com/repos/{owner}/{repo}/issues/{number}/comments"
```

### Comments

```bash
# List issue/PR comments
curl -sS -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{number}/comments"
```

## Pagination

When results may span multiple pages, check the `Link` response header. Parse with:

```bash
curl -sI -H "Authorization: Bearer $(cat ~/.config/github-rest/token)" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?per_page=100" \
  | grep -oP 'rel="next"'
```

If present, fetch subsequent pages by following the `&page=N` parameter.

## Error handling

On failure, the API returns a JSON body with a `message` field. Check HTTP status code with `-w "%{http_code}"` and pipe the body through `jq '.message'`.

- `401` = token missing/expired, or the file has more than one line (anything extra on line 1 breaks `$(cat ...)` — verify with `wc -l`, never print the file). `403` = the token lacks scope (PR writes need `repo`; git push needs `repo` or `Contents: write`). Ask the user to replace the token file; do not retry in a loop.
