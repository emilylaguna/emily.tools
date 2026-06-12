---
name: watch
description: >
  Watch something and get notified when it changes — GitHub PRs (single or a
  repo's whole queue), CI/workflow runs, git branches, files, folders, URLs, or
  any shell command. Trigger when the user asks to watch / monitor / keep tabs
  on / be notified about / alerted when anything changes. Pick the right target
  from the request and set up a Monitor; fall back to a raw command watch when
  nothing else fits.
argument-hint: '<thing to watch> [every <seconds>]'
allowed-tools: Bash, Monitor, TaskStop
---

Set up a `Monitor` that polls a target and emits one event line per change.
Everything routes through the `watch` harness:

```
watch <child> <interval-seconds> <args...>
```

The harness loops the child, gives it persistent state, and streams each event to stdout. Pick the child from what they want to
watch:

## watch-pr — one GitHub PR

```
pr:comment_added        <repo>#<pr> by=<user> :: <body>
pr:inline_comment_added <repo>#<pr> by=<user> file=<path>:<line> [reply_to=<id>] :: <body>
pr:review_submitted     <repo>#<pr> by=<user> state=<APPROVED|CHANGES_REQUESTED|COMMENTED|DISMISSED> :: <body>
pr:check_changed        <repo>#<pr> check=<name> <FROM>→<TO>
pr:merged               <repo>#<pr>
pr:closed               <repo>#<pr>
```

`inline_comment_added` carries `reply_to=<id>` only when it continues a thread.
**Push**: comments, reviews, a check flipping to FAILURE, merge/close. **Stop**:
auto-stops on merge or close.

## watch-prs — a repo's PR queue

```
prs:opened <repo>#<pr> by=<author> :: <title>
prs:merged <repo>#<pr>        # only with --state all
prs:closed <repo>#<pr>        # only with --state all
```

## watch-ci — a GitHub Actions run

```
ci:status_changed <repo> run=<id> <FROM>→<TO>      # queued|in_progress|completed
ci:completed      <repo> run=<id> conclusion=<success|failure|cancelled|timed_out|...>
```

## watch-branch — a git branch

One event per commit, oldest first. 

```
branch:commit <repo>@<branch> sha=<short> by=<author> :: <subject>
```

## watch-file — a single file

```
file:created  <abs-path> size=<bytes>     # warm boot only: file came back
file:modified <abs-path> size=<bytes>
file:deleted  <abs-path>                  # emits then stops
```

Content-hash based — a bare `touch` won't fire.

## watch-folder — a folder, recursive

```
folder:added     <abs-path> size=<bytes>
folder:modified  <abs-path> size=<bytes>
folder:deleted   <abs-path>
folder:truncated <N> more                 # flood guard: >200 events in one iter
```

Hidden files (`.git`, `.DS_Store`, `.venv`) skipped by default.

## watch-url — an HTTP(S) endpoint

```
url:status_changed   <url> <FROM>→<TO>
url:content_changed  <url> bytes=<n>       # content mode only
url:unreachable      <url> :: <reason>
url:recovered        <url> status=<code>
```

`--status-only` skips body fetching.

## watch-cmd — any shell command (fallback)

```
cmd:changed bytes=<n> lines=<n> :: <first-200-chars>
cmd:failed  exit=<code>
```

Runs via `bash -c`; full last output saved to `$WATCH_STATE_DIR/last_output`.

## State & cold boot (all children)

State is keyed by `(child, args)` and persists
across sessions — restart tomorrow and it picks up where it left off. The
first-ever run for a watch identity is a **cold boot**: the backlog is silenced
(only terminal signals like PR merge/close or CI completion still emit). Every
later run is a warm boot that diffs against saved state. Reset with
`watch-clear <id>`; inspect with `watch-list`.

**Prefer a dedicated child over `watch-cmd`** — they emit richer, typed events.
Use `watch-cmd` only when the target is genuinely ad-hoc (a `kubectl` query, a
`jq` pipeline, etc.). For streaming log lines (`tail -F | grep`), use the
`Monitor` tool directly — that's already the right primitive.

## Managing watches

- `watch-list` — show all persisted watches (`--json` for machine output).
- `watch-clear <id>` / `watch-clear --match <substr>` / `watch-clear --all` — reset state.
