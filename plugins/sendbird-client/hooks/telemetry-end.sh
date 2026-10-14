#!/usr/bin/env bash
# PostToolUse Agent (Claude Code) or SubagentStop (Codex): append an end record (duration + outcome) IF opted in. Never blocks. No network. No PII.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json
telemetry_enabled || exit 0
agent="$(jget .tool_input.subagent_type)"; [ -n "$agent" ] || agent="$(jget .agent_type)"; [ -n "$agent" ] || agent="unknown"
# A Codex subagent that the citation check sends back gets a second SubagentStop; count only the last.
if [ "$(jget .hook_event_name)" = SubagentStop ] \
  && printf '%s' "$HOOK_JSON" | bash "$HERE/unsourced-claim-warn.sh" 2>/dev/null | jq -e '.decision == "block"' >/dev/null 2>&1; then
  exit 0
fi
dur="$(jget .duration_ms)"
id="$(jget .agent_id)"; mark=""; [ -z "$id" ] || mark="$(agent_start_mark "$id")"
if [ -z "$dur" ] && [ -n "$mark" ] && [ -r "$mark" ]; then
  start="$(cat "$mark")"; case "$start" in ''|*[!0-9]*) ;; *) dur=$(( $(now_ms) - start )) ;; esac
fi
[ -z "$mark" ] || rm -f "$mark"
[ -n "$dur" ] || dur="0"
outcome="$(jget .tool_response.status)"
[ -z "$outcome" ] && [ "$(jget .hook_event_name)" = SubagentStop ] && outcome="completed"
[ -n "$outcome" ] || outcome="unknown"
log="$(telemetry_log_path)"; mkdir -p "$(dirname "$log")"
jq -cn --arg a "$agent" --argjson d "${dur:-0}" --arg o "$outcome" \
  '{event:"end", agent:$a, duration_ms:$d, outcome:$o}' >> "$log" 2>/dev/null || true
exit 0
