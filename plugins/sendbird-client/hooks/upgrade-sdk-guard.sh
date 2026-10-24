#!/usr/bin/env bash
# PreToolUse Agent (Codex: spawn_agent): skills/upgrade-sdk/SKILL.md hands the upgrade to the platform
# agent (step 7) only after step 4 read the curated rules for the target versions:
# knowledge/curated/<platform>/setup.md, hosts/<host>.md, and products/uikit.md when UIKit is installed
# (hook-helpers.sh upgrade_missing_reads). In five 2026-10 TC rounds the plan was made without them, so a
# rule such as "keep the app's Chat SDK inside the range UIKit declares" was never checked.
# When this turn runs upgrade-sdk, has looked up a version (latest-version.sh), and has not read those
# files, the hand-off is denied once with their names. A second hand-off in the same turn goes through,
# so a read this hook cannot see never stops the upgrade. What the turn did comes from
# hooks/session-state.sh (turn-trace), so this works without a session transcript.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

trace_has "skill upgrade-sdk" || exit 0
trace_lines | grep -q '^latest ' || exit 0
trace_has "guard upgrade-reads" && exit 0
missing="$(upgrade_missing_reads "$(jget '.cwd')" | paste -sd ',' - | sed 's/,/, /g')"
[ -n "$missing" ] || exit 0
f="$(session_state_file turn-trace)"
[ -n "$f" ] && printf 'guard upgrade-reads\n' >> "$f" 2>/dev/null

jq -n --arg m "$missing" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("Upgrade step check (Sendbird plugin, skills/upgrade-sdk/SKILL.md step 4): before the plan goes to the platform agent, read " + $m + " (the Read tool, or cat in a shell), check the plan against their rules for the target versions, and cite each rule you apply. Then hand the plan to the agent again.")
  }
}'
exit 0
