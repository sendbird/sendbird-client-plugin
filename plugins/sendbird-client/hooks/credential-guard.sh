#!/usr/bin/env bash
# PreToolUse write/shell guard: block tool calls that contain a credential literal.
# Claude Code sends Write/Edit/MultiEdit/Bash; Codex sends Bash and apply_patch.
#
# Thin plugin-side wrapper: reads the Claude Code hook JSON, extracts the body being
# written or run, and delegates the actual pattern check to core/commands/check-credential.sh
# (a pure, Claude-Code-agnostic command a future CLI can call directly). This file's
# only job is translating hook JSON in and a hook-shaped decision out.
# shellcheck source=lib/hook-helpers.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/hook-helpers.sh"
read_stdin_json guard

tool="$(jget .tool_name)"
case "$tool" in
  Write) body="$(jget .tool_input.content)"; path="$(jget .tool_input.file_path)";;
  Edit)  body="$(jget .tool_input.new_string)"; path="$(jget .tool_input.file_path)";;
  MultiEdit) body="$(printf '%s' "$HOOK_JSON" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)"; path="$(jget .tool_input.file_path)";;
  Bash) body="$(jget .tool_input.command)"; path="shell command";;
  apply_patch) body="$(patch_added)"; path="$(patch_paths | paste -sd, -)";;
  *) exit 0;;
esac
[ -n "$body" ] || exit 0

CORE="$(cd "$HERE/../core/commands" && pwd)"
hit="$(printf '%s' "$body" | bash "$CORE/check-credential.sh" | jq -r '.hit // empty')"
[ -z "$hit" ] && exit 0

reason="Possible secret ($hit) in ${path:-the edited file}. Use an environment variable or secret manager; do not write or pass credential literals."
# a session, access, or auth token given a string literal, a placeholder included (core/commands/check-credential.sh)
case "$hit" in *"token literal"*)
  reason="$reason A session or access token is never a string literal in app code, a placeholder such as \"TODO_SESSION_TOKEN\" included: read it from the app's token source. When the app has none, follow docs/AGENT_CONTRACT.md: for an authenticated session, one app function fetches the token from the customer's server (no URL or token in it) and the token server goes under manualSteps; for AI Agent user details, keep the anonymous session and pass the details in the context object (section 7)." ;;
esac
jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
