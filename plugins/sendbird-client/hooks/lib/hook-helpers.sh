#!/usr/bin/env bash
# Shared helpers for hook scripts. Source this file. Reads stdin JSON once.

# read_stdin_json : caches the stdin payload into $HOOK_JSON (empty if none/not json)
read_stdin_json() {
  HOOK_JSON="$(cat 2>/dev/null || true)"
  if ! printf '%s' "$HOOK_JSON" | jq -e . >/dev/null 2>&1; then HOOK_JSON='{}'; fi
}

# jget <jq-path> : echo a string field from $HOOK_JSON ('' if absent)
jget() { printf '%s' "$HOOK_JSON" | jq -r "$1 // empty" 2>/dev/null; }

# emit_warning <text> : warn-only output (exit 0 in caller). Never blocks.
emit_warning() { jq -n --arg m "$1" '{systemMessage: $m}'; }

# telemetry_enabled : 0 if opt-in flag is true (env TELEMETRY_OPT_IN or config/plugin-config.json)
telemetry_enabled() {
  [ "${TELEMETRY_OPT_IN:-}" = "true" ] && return 0
  local cfg="${CLAUDE_PLUGIN_ROOT:-.}/config/plugin-config.json"
  [ -f "$cfg" ] || cfg="config/plugin-config.json"
  if [ -f "$cfg" ]; then
    [ "$(jq -r '.telemetry.enabled // false' "$cfg" 2>/dev/null)" = "true" ] && return 0
  fi
  return 1
}

# telemetry_log_path : where the JSONL lives (override with TELEMETRY_LOG for tests)
telemetry_log_path() { printf '%s' "${TELEMETRY_LOG:-$HOME/.claude/sendbird-client-telemetry.jsonl}"; }
