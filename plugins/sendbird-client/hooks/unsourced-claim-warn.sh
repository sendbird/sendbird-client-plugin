#!/usr/bin/env bash
# SubagentStop (Claude Code: the plugin's own agents; Codex: every agent) or PostToolUse Agent (Claude
# Code): flag a subagent answer that contains API-shaped identifiers / code / docs URLs but no citation
# marker. Enforces §6.4 for agent output.
# SubagentStop carries the answer in last_assistant_message, also for a background agent, and the
# subagent is sent back once to cite (stop_hook_active lets the second stop pass; it cannot loop).
# PostToolUse Agent only warns: it sees the answer of a foreground agent (tool_response.content), and
# for a background agent only the launch notice (status async_launched, no content), so it is silent.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

text="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_response.content[]?.text // empty' 2>/dev/null)"
[ -n "$text" ] || text="$(jget .last_assistant_message)"
[ -n "$text" ] || exit 0

needs_cite=0
printf '%s' "$text" | grep -Eq '```' && needs_cite=1
printf '%s' "$text" | grep -Eq '\b[A-Z][A-Za-z0-9]*(Channel|Message|Manager|Delegate|Handler|Params|Provider|Module)\b' && needs_cite=1
printf '%s' "$text" | grep -Eq 'https?://[A-Za-z0-9./_-]+' && needs_cite=1
[ "$needs_cite" -eq 0 ] && exit 0

if printf '%s' "$text" | grep -Eq '(source:|verified against|from sendbird/|#discussions/|:[0-9]+\b|knowledge/(imports|curated)/)'; then
  exit 0
fi
msg="⚠️ This answer names Sendbird APIs / code / a docs URL but includes no citation. Per the No-Fabrication policy, re-emit with a verifiable source for each symbol (source: <knowledge/imports path | public mirror | sendbird.com/docs URL>), or state 'I don't know — here's what I checked'."
if [ "$(jget .hook_event_name)" = SubagentStop ]; then
  [ "$(jget .stop_hook_active)" = "true" ] && exit 0
  jq -n --arg m "$msg" '{decision: "block", reason: $m, systemMessage: $m}'
  exit 0
fi
emit_warning "$msg"
exit 0
