#!/usr/bin/env bash
# PostToolUse Agent: append an end record (duration + outcome) IF opted in. Never blocks. No network. No PII.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json
telemetry_enabled || exit 0
agent="$(jget .tool_input.subagent_type)"; [ -n "$agent" ] || agent="unknown"
dur="$(jget .duration_ms)"; [ -n "$dur" ] || dur="0"
outcome="$(jget .tool_response.status)"; [ -n "$outcome" ] || outcome="unknown"
log="$(telemetry_log_path)"; mkdir -p "$(dirname "$log")"
jq -cn --arg a "$agent" --argjson d "${dur:-0}" --arg o "$outcome" \
  '{event:"end", agent:$a, duration_ms:$d, outcome:$o}' >> "$log" 2>/dev/null || true
exit 0
