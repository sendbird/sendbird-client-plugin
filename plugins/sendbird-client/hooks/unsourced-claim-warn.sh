#!/usr/bin/env bash
# PostToolUse Agent: warn (never block) if the subagent's returned text contains API-shaped
# identifiers / code / docs URLs but no citation marker. Enforces §6.4 for agent output.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

text="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_response.content[]?.text // empty' 2>/dev/null)"
[ -n "$text" ] || exit 0

needs_cite=0
printf '%s' "$text" | grep -Eq '```' && needs_cite=1
printf '%s' "$text" | grep -Eq '\b[A-Z][A-Za-z0-9]*(Channel|Message|Manager|Delegate|Handler|Params|Provider|Module)\b' && needs_cite=1
printf '%s' "$text" | grep -Eq 'https?://[A-Za-z0-9./_-]+' && needs_cite=1
[ "$needs_cite" -eq 0 ] && exit 0

if printf '%s' "$text" | grep -Eq '(source:|verified against|from sendbird/|#discussions/|:[0-9]+\b|knowledge/(imports|curated)/)'; then
  exit 0
fi
emit_warning "⚠️ This answer names Sendbird APIs / code / a docs URL but includes no citation. Per the No-Fabrication policy, re-emit with a verifiable source for each symbol (source: <knowledge/imports path | public mirror | sendbird.com/docs URL>), or state 'I don't know — here's what I checked'."
exit 0
