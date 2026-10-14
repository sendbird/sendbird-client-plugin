#!/usr/bin/env bash
# PostToolUse Agent (Claude Code) or SubagentStop (Codex): flag a subagent answer that contains API-shaped
# identifiers / code / docs URLs but no citation marker. Enforces §6.4 for agent output.
# Claude Code shows a warning. Codex shows systemMessage only to the user, so on SubagentStop the
# subagent is sent back once to cite (stop_hook_active lets the second stop pass; it cannot loop).
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
