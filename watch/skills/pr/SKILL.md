---
name: pr
description: Watch a specific GitHub PR for new comments, reviews, and CI check changes. Trigger when the user asks to watch/monitor/keep tabs on a PR, be notified about PR activity, or know when comments/reviews land. Scope is ONE PR — for a whole repo's PR list, use watch:prs instead.
argument-hint: '<owner/repo>#<pr> [every <seconds>]'
---

# /watch:pr

Monitor a single GitHub PR and surface new activity to Charlie via the `Monitor` tool.

## What it catches

- New top-level PR comments (`/issues/<pr>/comments`)
- New inline diff comments (`/pulls/<pr>/comments`) — tracked separately, carry file+line
- New reviews (APPROVED / CHANGES_REQUESTED / COMMENTED / DISMISSED)
- Check-run status changes (e.g. tests going from `PENDING` → `FAILURE`)
- PR close or merge — stops the watch automatically

## Collecting arguments

Extract:

- `repo` in `owner/repo` form (e.g. `Charlieverse-ai/charlieverse`)
- `pr` the PR number
- `interval` in seconds (default 60; use 30 for "fast", 300 for "occasional")

Parsing rules:

- Full URL (`https://github.com/owner/repo/pull/123`) → parse both.
- Bare number (`#123` / `PR 123`) → resolve repo with `gh repo view --json nameWithOwner --jq .nameWithOwner` from cwd.
- If neither yields a repo, ask the user once for `owner/repo`.

## Invocation

Call the `Monitor` tool with:

- `command`: `watch watch-pr <interval> <repo> <pr>`
- `description`: `PR #<pr> in <repo>`
- `persistent`: `true`

`watch` and `watch-pr` are on PATH via the plugin's `bin/` — no absolute paths.

## Event format

Each Monitor notification is one line of the form:

```
pr:comment_added        <repo>#<pr> by=<user> :: <body>
pr:inline_comment_added <repo>#<pr> by=<user> file=<path>:<line> [reply_to=<id>] :: <body>
pr:review_submitted     <repo>#<pr> by=<user> state=<STATE> :: <body>
pr:check_changed        <repo>#<pr> check=<name> <FROM>→<TO>
pr:merged               <repo>#<pr>
pr:closed               <repo>#<pr>
```

Leading tag `pr:<event>` is the routing key. Body tails are normalized to single-line and truncated to 200 chars. `inline_comment_added` includes `reply_to=<id>` only when it's a reply to another inline comment (thread continuation).

## State persistence

State is keyed by `(child, args)` hash and persists across sessions in `$CLAUDE_PLUGIN_DATA/watches/<id>/`. Stopping and restarting the same watch tomorrow picks up where it left off — PRs opened overnight emit as new events on the first tick.

First-ever run for a watch identity is a **cold boot** (backlog silenced; only PR close/merge emits). Every subsequent run — including after restarts — is a warm boot and diffs against persisted state.

To reset: `watch-clear <id>` or `watch-clear --match <substr>`. List watches: `watch-list`.

## Routing decisions

Per event, decide whether to `PushNotification` or just log:

- **Push now**: `pr:review_submitted state=CHANGES_REQUESTED`, `pr:check_changed <*>→FAILURE`, `pr:merged`, `pr:closed`, `pr:inline_comment_added` when the body reads as an action request ("can you…", "please change…", "this is wrong").
- **Log only**: `pr:comment_added` (routine drive-bys), `pr:inline_comment_added` that's a passive note ("nit:", "TIL"), `pr:check_changed` into passing/neutral states.
- **Dispatch a reviewer**: if the user set the watch up with "and review new ones" intent, dispatch a code-reviewer subagent on relevant events — but confirm once before doing it unattended.

## Stop conditions

- Script auto-exits when the PR merges or closes.
- Early cancel: `TaskStop` with the Monitor task id.
