#!/usr/bin/env bash
# Keeps what the plugin's checks need per session in the plugin data folder, so they work without a
# session transcript: `claude -p --no-session-persistence` writes none, and a check that reads only
# transcript_path skipped itself there (a 2026-10 TC round: a pasted session token reached a Skill
# argument, an agent brief, and the first result of a non-interactive run). Never blocks, never prints.
#
# Usage: session-state.sh prompt|tool|agent-start|agent-stop   (the hook event)
#   prompt       UserPromptSubmit (Claude Code and Codex send the text as .prompt): the SHA-256 and
#                length of each token the request pastes (hook-helpers.sh request_tokens) go to
#                request-tokens-<session_id>. The token itself is never written.
#                (final-answer-gate.sh, token-relay-guard.sh). A request that asks for a build of the
#                project (prompt_asks_build) writes build-asked-<session_id>, and one that does not
#                removes it (build-command-guard.sh). The request also starts this turn's trace
#                (turn-trace-<session_id>) again, with a "skill <name>" line when it names a skill as
#                /<plugin>:<name> or $<plugin>:<name> ("other-skill sendbird-cli:<name>" for a Sendbird CLI plugin skill).
#                When destructive-command-guard.sh denied a Sendbird CLI delete in the last turn (Codex or a
#                non-interactive run), a prompt that says yes and names its targets writes
#                destructive-confirmed-<session_id>, which lets that command run once.
#   tool         PreToolUse: what the call shows of a skill's steps goes into the turn's trace
#                (hook-helpers.sh trace_lines): the skill it starts (the Skill tool, or a shell read of
#                skills/<name>/SKILL.md in Codex; a Sendbird CLI plugin skill goes in as other-skill),
#                the curated files it reads (the Read tool, or a shell
#                command such as cat or sed naming knowledge/curated/**/*.md), and its
#                tools/local-sdk/latest-version.sh lookups (final-answer-gate.sh, upgrade-sdk-guard.sh).
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
    trace="$(session_state_file turn-trace)"
    if [ -n "$trace" ]; then
      rm -f "$trace"
      s="$(printf '%s' "$prompt" | sed -nE '1s#^[[:space:]]*[/$](([A-Za-z0-9_-]+:)?[a-z0-9-]+)([[:space:]].*)?$#\1#p')"
      l="$(skill_trace_line "$s")"
      [ -z "$l" ] || { mkdir -p "$(dirname "$trace")" 2>/dev/null && printf '%s\n' "$l" >> "$trace"; }
    fi
    # A destructive CLI command destructive-command-guard.sh denied in the last turn waits for this prompt:
    # a yes that names every target of it (or a yes, for a command with no target) confirms it once.
    # Any other prompt drops it, and a confirmation not used in its turn is dropped by the next prompt.
    confirmed="$(session_state_file destructive-confirmed)"; pending="$(session_state_file destructive-pending)"
    if [ -n "$confirmed" ]; then
      rm -f "$confirmed"
      if [ -s "$pending" ] && prompt_confirms "$prompt"; then
        named=1
        while IFS= read -r t; do
          [ -n "$t" ] || continue
          printf '%s' "$prompt" | grep -Fq -- "$t" || { named=0; break; }
        done < <(sed -n 's/^target //p' "$pending")
        [ "$named" -eq 1 ] && cp "$pending" "$confirmed" 2>/dev/null
      fi
      rm -f "$pending"
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
  tool)
    tool="$(jget '.tool_name')"
    case "$tool" in
      Skill)
        lines="$(skill_trace_line "$(jget '.tool_input.skill')")" ;;
      Read)
        lines="$(jget '.tool_input.file_path' | curated_paths | sed 's/^/read /')" ;;
      Bash)
        c="$(jget '.tool_input.command')"
        lines="$(
          printf '%s\n' "$c" | grep -Eo '(sendbird-cli/([^/[:space:]"'"'"']+/)?)?skills/[a-z0-9-]+/SKILL\.md' \
            | sed -E -e 's#^sendbird-cli/.*skills/([a-z0-9-]+)/SKILL\.md$#other-skill sendbird-cli:\1#' \
                     -e 's#^skills/([a-z0-9-]+)/SKILL\.md$#skill \1#'
          if printf '%s\n' "$c" | grep -Eq '(^|[^A-Za-z0-9_-])(cat|sed|head|tail|awk|nl|less|more|bat|grep|rg|perl|python3?)([^A-Za-z0-9_-]|$)'; then
            printf '%s\n' "$c" | curated_paths | sed 's/^/read /'
          fi
          printf '%s\n' "$c" | latest_calls
        )" ;;
      *) lines="" ;;
    esac
    [ -n "$lines" ] || exit 0
    f="$(keep turn-trace)"
    printf '%s\n' "$lines" | sed '/^$/d' >> "$f"
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
