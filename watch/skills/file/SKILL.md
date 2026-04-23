---
name: file
description: Watch a single file for content changes. Trigger when the user asks to watch a file, know when a file changes, or be alerted on edits. Uses content hash — a bare `touch` without real edits will NOT fire.
argument-hint: '<path> [every <seconds>]'
---

# /watch:file

Poll a file and emit an event when its content hash changes.

## Collecting arguments

- `path` — file path (absolute preferred; relative resolves from cwd at invocation time).
- `interval` seconds (default 5 for active editing, 30 for passive).

## Invocation

```
command:     watch watch-file <interval> <path>
description: file:<basename>
persistent:  true
```

## Event format

```
file:created  <abs-path> size=<bytes>     # warm boot only: file came back
file:modified <abs-path> size=<bytes>
file:deleted  <abs-path>                  # emits then stops the watch
```

## State persistence

Keyed by `(path,)`. Cold boot silently seeds the hash. Warm boot compares against the last saved hash — useful for "notify me if this config file got edited while I was away."

## Routing decisions

- **Push now**: `file:deleted` (usually unexpected), or any `file:modified` on a config/infra file the user flagged as important.
- **Log only**: routine edits during active development — the user is watching the editor, not waiting on you.
- **Dispatch**: on `file:modified` to a test file, kick off the test runner. On `file:modified` to a config file, run a validator. Only do this unattended if the user set up the watch with that intent.

## Stop conditions

Auto-stops when a previously-existing file is deleted (exit 1). If the file never existed on cold boot, keeps polling — useful for "watch for this file to appear."
