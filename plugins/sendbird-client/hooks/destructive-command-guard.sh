#!/usr/bin/env bash
# PreToolUse Bash guard: a Sendbird CLI command that deletes, revokes, or deactivates
# something and skips the CLI's own confirmation (--yes / -y) needs a person to approve it.
#
# The CLI never prompts in normal use (its users are agents), so an agent can add --yes
# itself, or be told to by text it read (prompt injection). It never blocks read-only commands or
# a destructive command without --yes (the CLI stops on those by itself).
#
# - Claude Code, interactive: the hook returns "ask", and Claude Code shows the user a confirmation
#   prompt (in a plain -p run nobody can answer it, so the call is denied and Claude reads the reason).
# - Codex (its PreToolUse input carries turn_id; Claude Code's does not), and any run with
#   SENDBIRD_NONINTERACTIVE on: "ask" is not a stop there. Codex exec 0.164.0 ran
#   `sendbird ... chat user delete --id <user> --yes` right after this hook answered "ask" (a 2026-10 TC
#   run, confirmed with a debug log of this hook's input and output). So the hook denies the command and
#   tells the agent to stop and ask the customer. The customer's next prompt confirms it by naming the
#   command's targets (the values after the action, such as the user ID) with a yes
#   (hooks/session-state.sh prompt writes destructive-confirmed-<session_id>); then the same delete of
#   the same targets runs once, and the confirmation is used up. A part that also has --dry-run only
#   previews, so it is let through.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json guard

[ "$(jget .tool_name)" = "Bash" ] || exit 0
cmd="$(jget .tool_input.command)"
[ -n "$cmd" ] || exit 0

# deny mode: a host or run where "ask" stops nothing (see above)
deny_mode=0
if [ -n "$(jget .turn_id)" ] || is_noninteractive; then deny_mode=1; fi

# Normalize before matching: quotes, backticks, and command substitution become spaces, so a
# command wrapped as bash -c "sendbird ...", sh -c'...', zsh -c, eval "...", $(...), or with a
# quoted program name reads as plain words. Then look at each simple command (split on
# ; && || | and newlines) on its own. An env or sudo prefix needs nothing: the CLI name is
# matched anywhere after a space.
norm="$(printf '%s\n' "$cmd" | tr "\"'\`()" '     ')"
hits=""
while IFS= read -r part; do
  # the CLI: sendbird, sendbird-cli, or npx/pnpm dlx/bunx @sendbird/cli
  printf '%s' "$part" | grep -Eq '(^|[[:space:]/])(sendbird|sendbird-cli|@sendbird/cli(@[^[:space:]]*)?)([[:space:]]|$)' || continue
  printf '%s' "$part" | grep -Eq '(^|[[:space:]])(delete|revoke|deactivate)([[:space:]]|$)' || continue
  printf '%s' "$part" | grep -Eq '(^|[[:space:]])(--yes|-y)([[:space:]=]|$)' || continue
  if [ "$deny_mode" -eq 1 ] && printf '%s' "$part" | grep -Eq '(^|[[:space:]])--dry-run([[:space:]=]|$)'; then continue; fi
  hits="$hits$(printf '%s' "$part" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g; s/ $//')"$'\n'
done < <(printf '%s\n' "$norm" | sed -E 's/(&&|\|\||;|\|)/\n/g')
[ -n "$hits" ] || exit 0
hit="$(printf '%s' "$hits" | head -1)"

if [ "$deny_mode" -eq 0 ]; then
  jq -n --arg c "$(printf '%s' "$hit" | cut -c1-200)" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: ("This Sendbird CLI command deletes, revokes, or deactivates something and skips the CLI confirmation with --yes: " + $c + "\nA person must approve it. Run it with --dry-run first and show the user what it will change.")
  }
}'
  exit 0
fi

# The targets of each destructive part (destructive_targets in hooks/lib/hook-helpers.sh), one per line.
targets="$(while IFS= read -r p; do [ -n "$p" ] && destructive_targets "$p"; done <<< "$hits" | awk 'NF && !seen[$0]++')"
confirmed="$(session_state_file destructive-confirmed)"
pending="$(session_state_file destructive-pending)"
# A confirmation from the customer's latest prompt lets this command through once, when it names every
# target of the command (a command with no target needs the confirmation of that same command).
if [ -n "$confirmed" ] && [ -s "$confirmed" ]; then
  ok=1
  if [ -n "$targets" ]; then
    while IFS= read -r t; do grep -Fxq -- "target $t" "$confirmed" || { ok=0; break; }; done <<< "$targets"
  else
    grep -Fxq -- "command $(printf '%s' "$hits" | paste -sd ';' -)" "$confirmed" || ok=0
  fi
  if [ "$ok" -eq 1 ]; then rm -f "$confirmed"; exit 0; fi
fi
# Remember what waits for a confirmation, for hooks/session-state.sh prompt.
if [ -n "$pending" ]; then
  mkdir -p "$(dirname "$pending")" 2>/dev/null
  { umask 077
    printf 'command %s\n' "$(printf '%s' "$hits" | paste -sd ';' -)"
    [ -z "$targets" ] || printf '%s\n' "$targets" | sed 's/^/target /'
  } > "$pending" 2>/dev/null
fi

named="$(printf '%s' "$targets" | paste -sd ',' - | sed 's/,/, /g')"
jq -n --arg c "$(printf '%s' "$hit" | cut -c1-200)" --arg t "$named" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("Destructive command check (Sendbird plugin): this Sendbird CLI command deletes, revokes, or deactivates something and skips the CLI confirmation with --yes: " + $c + "\nIt was NOT run, and this session cannot show the customer an approval prompt. Do not run it another way (without --yes, in a script, or through another tool). Stop this turn now: show the customer the command and what it will change (run it with --dry-run to preview), and ask them to confirm it in their next message"
      + (if $t != "" then " by naming " + $t + " and saying yes" else " with a yes" end)
      + ". In a non-interactive run, end with status needs_input and that question. Run the command only after that message confirms it; the confirmation covers this command once.")
  }
}'
exit 0
