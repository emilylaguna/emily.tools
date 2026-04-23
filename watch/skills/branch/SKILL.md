---
name: branch
description: Watch a git branch (local or remote) for new commits. Trigger when the user asks to watch a branch, know when someone pushes to main, or track upstream changes. Fires one event per commit in chronological order.
argument-hint: '<repo-path> <branch> [--remote <remote>]'
---

# /watch:branch

Poll a git branch and emit one event per new commit.

## Collecting arguments

- `repo_path` — absolute path to the git working tree. Default to cwd if the user didn't specify and cwd is a git repo.
- `branch` — branch name (e.g. `main`, `release/v2`).
- Optional `--remote <name>` to track a remote branch. The script runs `git fetch --quiet <remote> <branch>` each tick. Without `--remote`, it tracks a local branch only.
- `interval` seconds (default 30 for active local branches, 120 for remotes).

## Invocation

Local branch:

```
command:     watch watch-branch <interval> <repo-path> <branch>
description: branch:<branch>
persistent:  true
```

Remote branch:

```
command:     watch watch-branch <interval> <repo-path> <branch> --remote origin
description: branch:origin/<branch>
persistent:  true
```

## Event format

```
branch:commit <repo>@<branch> sha=<short> by=<author> :: <subject>
```

One event per commit, chronological order (oldest first). If 20 commits land between polls, 20 lines emit.

## State persistence

Keyed by `(repo_path, branch, --remote)`. State file stores the last seen HEAD sha. Warm boot walks the commit range `prev_head..curr_head` and emits each commit.

## Routing decisions

- **Push now**: commits to a branch the user is waiting on (release, hotfix, coworker's PR branch). Especially if the commit count in one tick is ≥3 — that's a landed PR.
- **Log only**: self-commits on a branch the user is actively working on — they know what they just did.
- **Dispatch**: on new commits to `main` or a watched release branch, optionally run a local `git pull` or `/review` against the incoming commits. Only unattended if intent was set up that way.

## Stop conditions

No auto-stop. Cancel via `TaskStop`.

## Notes

- `--remote` mode calls `git fetch` every tick — bumps interval up if bandwidth matters.
- Script does not change HEAD or touch the working tree. Safe to run against a branch you have checked out.
