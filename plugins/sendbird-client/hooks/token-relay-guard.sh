#!/usr/bin/env bash
# PreToolUse Skill and Agent (Claude Code), Agent (Codex: the alias that covers spawn_agent): deny a call
# whose input repeats a token the customer pasted in a request of this session. The skill and the agent
# need to know that a token was given, never its value: in a 2026-10 TC round the main session passed a
# pasted test session token into a Skill argument and an agent brief. Every string in tool_input is
# checked, so the field names of each host's tool do not matter. The tokens are those of the latest
# request in the transcript and those hooks/session-state.sh saved as hashes (hook-helpers.sh
# text_repeats_request_token), so this also works without a transcript. Without jq it lets the call
# through: an "ask" on every Skill and Agent call would stop all work in a run nobody can answer.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

input="$(printf '%s' "$HOOK_JSON" | jq -r '[.tool_input | .. | strings] | join("\n")' 2>/dev/null)"
[ -n "$input" ] || exit 0
text_repeats_request_token "$input" || exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "Secret check (Sendbird Client plugin): this call passes a token value the customer pasted in the request. Make the call again with that value replaced by \"the token you provided\": say that the customer gave a token and what it is for, never the value or part of it. Code reads a token at run time (from the app'\''s token server or a session handler), so the value is never needed."}}'
exit 0
