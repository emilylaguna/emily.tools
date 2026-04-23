#!/usr/bin/env bash
# env.sh — shared bootstrap for watch-* scripts. Sourced by the harness
# and by any helper that needs $CLAUDE_PLUGIN_DATA.
#
# Monitor spawns its subprocess without inheriting plugin env vars from
# the parent Claude Code process, so CLAUDE_PLUGIN_DATA arrives empty
# even though the plugin IS active. Rather than force every caller to
# prepend it, we derive the value from the script's own location:
#
#   $HOME/.claude/plugins/cache/<container>/watch/bin/<script>
#                                ^^^^^^^^^^^^
#                                three dirs up from $0 gives <container>
#
# and use $HOME/.claude/plugins/data/<container> for state.

# usage:  watch_ensure_plugin_data "$0"
# sets and exports CLAUDE_PLUGIN_DATA if not already present.
watch_ensure_plugin_data() {
  local script_arg="$1"
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    return 0
  fi

  local script_real="$script_arg"
  if readlink -f / >/dev/null 2>&1; then
    # GNU readlink (Linux)
    script_real=$(readlink -f "$script_arg" 2>/dev/null || echo "$script_arg")
  elif command -v python3 >/dev/null 2>&1; then
    # macOS has BSD readlink which lacks -f; fall back to Python
    script_real=$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$script_arg" 2>/dev/null || echo "$script_arg")
  fi

  # script_real: $HOME/.claude/plugins/cache/<container>/<plugin>/bin/<script>
  # container = basename of 3 dirs up
  local bin_dir plugin_dir container_dir
  bin_dir=$(dirname "$script_real")
  plugin_dir=$(dirname "$bin_dir")
  container_dir=$(dirname "$plugin_dir")
  local container
  container=$(basename "$container_dir")

  # If we couldn't derive a sensible container (e.g. running from a dev
  # checkout outside the plugin cache), fall back to /tmp so the script
  # doesn't blow up — state just won't persist the "right" way.
  if [ -z "$container" ] || [ "$container" = "/" ] || [ "$container" = "." ]; then
    export CLAUDE_PLUGIN_DATA="${TMPDIR:-/tmp}/watch-plugin-data"
  else
    export CLAUDE_PLUGIN_DATA="$HOME/.claude/plugins/data/$container"
  fi

  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || true
}
