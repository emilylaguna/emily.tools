---
name: folder
description: Watch a folder recursively for file adds, modifications, and deletions. Trigger when the user asks to watch a directory, be notified about changes in a project folder, or track file-system activity. Uses mtime+size manifest; hidden files (.git, .DS_Store) skipped by default.
argument-hint: '<path> [--glob "<pattern>"] [every <seconds>]'
---

# /watch:folder

Maintain a manifest of files under a folder and emit events when files are added, modified, or deleted.

## Collecting arguments

- `path` — folder path.
- `interval` seconds (default 10 for active work, 60 for passive).
- Optional `--glob '<pattern>'` to scope to matching filenames (e.g. `'*.py'`). Pass it as a single quoted arg.

## Invocation

```
command:     watch watch-folder <interval> <path>
description: folder:<basename>
persistent:  true
```

With glob:

```
command:     watch watch-folder 10 <path> --glob "*.py"
```

## Event format

```
folder:added    <abs-path> size=<bytes>
folder:modified <abs-path> size=<bytes>
folder:deleted  <abs-path>
folder:truncated <N> more                # flood guard (>200 events in one iter)
```

## State persistence

Manifest at `$CLAUDE_PLUGIN_DATA/watches/<id>/manifest.json`. Cold boot silently seeds. Warm boot diffs against the saved manifest, so restarting a folder watch picks up files that appeared while the session was down.

## Routing decisions

- **Push now**: mass deletion (many `folder:deleted` in one tick), or changes to critical files the user flagged.
- **Log only**: routine saves during development.
- **Dispatch**: `folder:added` to a tests dir → run new test; `folder:modified` to a Python file → re-run linter. Only unattended with explicit intent.

## Stop conditions

No auto-stop. Cancel via `TaskStop`.

## Notes

- Hidden files (`.git`, `.DS_Store`, `.venv`) are skipped. If the user wants them, switch to `--glob '*'` — though that still skips `.`-prefixed paths by design.
- Very large directories (>10k files) will slow down. Use a narrower `--glob` or watch a subdirectory instead.
