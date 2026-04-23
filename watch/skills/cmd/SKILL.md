---
name: cmd
description: Watch any shell command's output and fire when it changes. The escape hatch for "watch this specific thing" when no dedicated watch skill fits — wrap a curl, a kubectl query, a jq pipeline, whatever. Trigger when the user describes a watch target that doesn't match pr/prs/file/folder/url/ci.
argument-hint: '"<shell-command>" [every <seconds>]'
---

# /watch:cmd

Run a shell command on an interval, hash its stdout, and emit when the output changes. The generic primitive behind everything else.

## Collecting arguments

- `cmd` — the shell command string. Quote it. The command runs via `bash -c`, so shell expansion, pipes, and env vars all work.
- `interval` seconds (default 30; pick higher for remote APIs, lower for local checks).

If the user's request can be expressed by another watch skill (PR, file, folder, URL, CI), PREFER that skill — dedicated skills give better events. Use `watch:cmd` only when the target is genuinely ad-hoc.

## Invocation

```
command:     watch watch-cmd <interval> "<shell-command>"
description: cmd:<short-summary>
persistent:  true
```

Example — watch a local process count:

```
command:     watch watch-cmd 15 "pgrep -fl 'my-daemon' | wc -l"
description: cmd:my-daemon count
```

## Event format

```
cmd:changed bytes=<n> lines=<n> :: <first-200-chars-of-output>
cmd:failed  exit=<code>
```

Full last output is saved to `$WATCH_STATE_DIR/last_output` for deeper inspection if Charlie needs it.

## State persistence

Keyed by hash of the command string, so the same command reuses state across sessions. Cold boot silently seeds. Warm boot emits on first change after resuming.

## Routing decisions

- **Push now**: `cmd:failed` (command stopped working), and `cmd:changed` events where the command was set up specifically to catch a condition (e.g. "ping until the server responds").
- **Log only**: routine output churn — if the command is noisy and the user's interest is "just let me know," rely on the preview and don't push every tick.

## Stop conditions

No auto-stop. Cancel via `TaskStop`.

## Tips for writing the command

- Keep stdout concise — the full output is hashed for change detection, but only the first 200 chars land in the notification.
- For "emit every new log line," prefer `tail -F | grep --line-buffered` via the `Monitor` tool directly instead of `watch:cmd` — Monitor is already the right primitive for streaming logs.
- Redirect stderr to stdout (`2>&1`) if you care about error output contributing to the change signal.
