#!/usr/bin/env bash
# Keeps what the plugin's checks need per session in the plugin data folder, so they work without a
# session transcript: `claude -p --no-session-persistence` writes none, and a check that reads only
# transcript_path skipped itself there (a 2026-10 TC round: a pasted session token reached a Skill
# argument, an agent brief, and the first result of a non-interactive run). Never blocks, never prints.
#
# Usage: session-state.sh prompt|agent-start|agent-stop   (the hook event)
#   prompt       UserPromptSubmit (Claude Code and Codex send the text as .prompt): the SHA-256 and
#                length of each token the request pastes (hook-helpers.sh request_tokens) go to
#                request-tokens-<session_id>. The token itself is never written.
#                (final-answer-gate.sh, token-relay-guard.sh). A request that asks for a build of the
#                project (prompt_asks_build) writes build-asked-<session_id>, and one that does not
#                removes it (build-command-guard.sh).
#   agent-start  SubagentStart (both hosts send .agent_id): the agent goes into agents-running-<session_id>.
#   agent-stop   SubagentStop: the agent leaves agents-running (hook-helpers.sh agent_pending), unless the
#                plugin's citation check sends it back once, as hooks/telemetry-end.sh counts it. Its
#                report (.last_assistant_message, both hosts) goes to agent-reports-<session_id> when it
#                has check lines or a symbol/source table, so final-answer-gate.sh can see that the final
#                answer carries them.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

event="${1:-}"
umask 077

# keep <kind> : this session's file of that kind, with its folder created; exits when there is none
keep() {
  local f
  f="$(session_state_file "$1")"
  [ -n "$f" ] || exit 0
  mkdir -p "$(dirname "$f")" 2>/dev/null || exit 0
  printf '%s' "$f"
}

case "$event" in
  prompt)
    prompt="$(jget '.prompt')"
    [ -n "$prompt" ] || exit 0
    b="$(session_state_file build-asked)"
    if [ -n "$b" ]; then
      if prompt_asks_build "$prompt"; then mkdir -p "$(dirname "$b")" 2>/dev/null && : > "$b"; else rm -f "$b"; fi
    fi
    tokens="$(request_tokens "$prompt")"
    [ -n "$tokens" ] || exit 0
    f="$(keep request-tokens)"
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      h="$(printf '%s' "$t" | sha256_hex)"
      [ -n "$h" ] && printf '%s %s\n' "${#t}" "$h" >> "$f"
    done <<< "$tokens"
    [ -s "$f" ] && { sort -u "$f" > "$f.tmp" && mv "$f.tmp" "$f"; } 2>/dev/null
    ;;
  agent-start)
    id="$(printf '%s' "$(jget '.agent_id')" | tr -c 'A-Za-z0-9_-' _)"
    [ -n "$id" ] || exit 0
    f="$(keep agents-running)"
    printf '%s\t%s\n' "$id" "$(date +%s)" >> "$f"
    ;;
  agent-stop)
    report="$(jget '.last_assistant_message')"
    if [ -n "$report" ] && { [ -n "$(printf '%s\n' "$report" | report_check_names)" ] \
        || [ -n "$(printf '%s\n' "$report" | report_source_files)" ]; }; then
      f="$(keep agent-reports)"
      printf '%s\n\n' "$report" >> "$f"
    fi
    id="$(printf '%s' "$(jget '.agent_id')" | tr -c 'A-Za-z0-9_-' _)"
    [ -n "$id" ] || exit 0
    f="$(session_state_file agents-running)"
    [ -n "$f" ] && [ -f "$f" ] || exit 0
    # an agent the citation check sends back once stops again later; remove it then
    if [ "$(jget '.stop_hook_active')" != "true" ] \
      && printf '%s' "$HOOK_JSON" | bash "$HERE/unsourced-claim-warn.sh" 2>/dev/null | jq -e '.decision == "block"' >/dev/null 2>&1; then
      exit 0
    fi
    awk -F'\t' -v id="$id" '$1 != id' "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
    ;;
esac
exit 0
