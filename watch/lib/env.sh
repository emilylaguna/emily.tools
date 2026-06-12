#!/usr/bin/env bash
# env.sh — shared bootstrap for watch-* scripts. Sourced by the harness
# (watch) and the management commands (watch-list, watch-clear).
#
# State lives in a fixed, plugin-independent home so the commands work
# identically whether they're invoked by Claude Code's Monitor tool or
# straight from a terminal. No plugin env vars required.
#
#   ~/.emily/watch/<watch-id>/...
#
# Override the root with WATCH_DATA_ROOT in the environment if you want
# state somewhere else (handy for tests).

# usage:  watch_init_data_root
# sets and exports WATCH_DATA_ROOT, creating it if needed.
watch_init_data_root() {
  export WATCH_DATA_ROOT="${WATCH_DATA_ROOT:-$HOME/.emily/watch}"
  mkdir -p "$WATCH_DATA_ROOT" 2>/dev/null || true
}
