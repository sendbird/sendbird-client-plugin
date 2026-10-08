#!/usr/bin/env bash
# PreToolUse Bash guard: a Sendbird CLI command that deletes, revokes, or deactivates
# something and skips the CLI's own confirmation (--yes / -y) needs a person to approve it.
#
# The CLI never prompts in normal use (its users are agents), so an agent can add --yes
# itself, or be told to by text it read (prompt injection). This hook returns "ask":
# Claude Code shows the user a confirmation prompt, and in a -p run where nobody can answer
# it, the call is denied and Claude reads the reason. It never blocks read-only commands or
# a destructive command without --yes (the CLI stops on those by itself).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

[ "$(jget .tool_name)" = "Bash" ] || exit 0
cmd="$(jget .tool_input.command)"
[ -n "$cmd" ] || exit 0

# Look at each simple command (split on ; && || | and newlines) on its own.
hit=""
while IFS= read -r part; do
  # the CLI: sendbird, sendbird-cli, or npx/pnpm dlx/bunx @sendbird/cli
  printf '%s' "$part" | grep -Eq '(^|[[:space:]/])(sendbird|sendbird-cli|@sendbird/cli(@[^[:space:]]*)?)([[:space:]]|$)' || continue
  printf '%s' "$part" | grep -Eq '(^|[[:space:]])(delete|revoke|deactivate)([[:space:]]|$)' || continue
  printf '%s' "$part" | grep -Eq '(^|[[:space:]])(--yes|-y)([[:space:]=]|$)' || continue
  hit="$part"; break
done < <(printf '%s\n' "$cmd" | sed -E 's/(&&|\|\||;|\|)/\n/g')
[ -n "$hit" ] || exit 0

jq -n --arg c "$(printf '%s' "$hit" | sed -E 's/^[[:space:]]+//' | cut -c1-200)" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: ("This Sendbird CLI command deletes, revokes, or deactivates something and skips the CLI confirmation with --yes: " + $c + "\nA person must approve it. Run it with --dry-run first and show the user what it will change.")
  }
}'
exit 0
