---
name: ci
description: Watch a GitHub Actions workflow run until it completes. Trigger when the user asks to watch a CI run, know when a build finishes, be alerted on workflow pass/fail, or babysit a deploy. Narrower than watch:pr — this tracks ONE run to completion.
argument-hint: '<owner/repo> <run-id>  OR  <owner/repo> --branch <branch>'
---

# /watch:ci

Poll a GitHub Actions workflow run until it reaches a terminal state, then emit the conclusion and stop.

## Collecting arguments

- `repo` in `owner/repo` form.
- `run_id` — the workflow run's database ID. If the user says "watch the latest run on branch foo" instead of giving an id, resolve it first:

```
gh run list --repo <repo> --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId'
```

If the user says "watch my last push's build" and there's a current repo in cwd, combine `gh repo view` + `git rev-parse --abbrev-ref HEAD` + the list command above.

- `interval` seconds (default 20 for active CI watching, 60 if you expect a long run).

## Invocation

```
command:     watch watch-ci <interval> <repo> <run-id>
description: ci:<repo> run <run-id>
persistent:  true
```

## Event format

```
ci:status_changed <repo> run=<id> <FROM>→<TO>
ci:completed      <repo> run=<id> conclusion=<success|failure|cancelled|timed_out|...>
```

`status` values: `queued`, `in_progress`, `completed`.
`conclusion` is meaningful only on `completed`.

## State persistence

Keyed by `(repo, run_id)`. One-shot by nature — once the run completes, the script exits 1 and the watch ends. State dir is still around for inspection; use `watch-clear` to clean up.

## Routing decisions

- **Push now**: always push on `ci:completed`. The user is waiting to know the result — that is the whole point of the watch.
  - `conclusion=success` → short celebratory push
  - `conclusion=failure` → push with the run URL so the user can jump straight to the logs
- **Log only**: intermediate `ci:status_changed` (queued → in_progress) unless the user explicitly wanted progress pings.

## Stop conditions

Auto-stops (`exit 1`) when `status=completed`.
