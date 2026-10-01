#!/usr/bin/env bash
# PreToolUse Agent: append a start record IF telemetry opted in. Never blocks. No network.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json
telemetry_enabled || exit 0
agent="$(jget .tool_input.subagent_type)"; [ -n "$agent" ] || agent="unknown"
log="$(telemetry_log_path)"; mkdir -p "$(dirname "$log")"
jq -cn --arg a "$agent" '{event:"start", agent:$a}' >> "$log" 2>/dev/null || true
exit 0
