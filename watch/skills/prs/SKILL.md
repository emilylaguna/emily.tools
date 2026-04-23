---
name: prs
description: Watch a GitHub repo for newly-opened PRs. Trigger when the user asks to watch a repo's PR queue, be notified about new PRs, or automate PR triage ("watch prs and dispatch a reviewer"). Scope is a whole repo — for a single PR, use watch:pr.
argument-hint: '<owner/repo> [every <seconds>]'
---

# /watch:prs

Poll a GitHub repo for newly-opened PRs and surface them to Charlie via the `Monitor` tool.

## Collecting arguments

- `repo` in `owner/repo` form. If the user is in a repo and says "watch this repo's PRs," resolve with `gh repo view --json nameWithOwner --jq .nameWithOwner`.
- `interval` seconds (default 120; 60 if they want fast, 600 for casual).
- Optional `--state all` to also track close/merge events for existing PRs. Default is `open` — new-PRs-only.

## Invocation

```
command:     watch watch-prs <interval> <repo>
description: PRs in <repo>
persistent:  true
```

## Event format

```
prs:opened <repo>#<pr> by=<author> :: <title>
prs:merged <repo>#<pr>        # only with --state all
prs:closed <repo>#<pr>        # only with --state all
```

## State persistence

Cold boot silently seeds the current set of open PRs. Warm boot (day-2) emits any PR opened since the last tick — including overnight PRs when the session restarts. State lives in `$CLAUDE_PLUGIN_DATA/watches/<id>/` keyed by `(repo, state_filter)` hash.

## Routing decisions

- **Push now**: `prs:opened` — a new PR is almost always an attention event.
- **Dispatch a code-reviewer**: if the user set up the watch with "and review new ones" intent, dispatch a `code-reviewer` subagent on each `prs:opened` event. Confirm once the first time so they know unattended reviews are firing.
- **Log only**: `prs:merged`/`prs:closed` — usually tracked per-PR by `watch:pr` instead.

## Stop conditions

No auto-stop. Cancel via `TaskStop` with the Monitor task id.
