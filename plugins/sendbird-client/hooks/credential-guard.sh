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

jq -n --arg reason "Possible secret ($hit) in ${path:-the edited file}. Use an environment variable or secret manager; do not write or pass credential literals." '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
