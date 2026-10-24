#!/usr/bin/env bash
# Stop hook: citation gate for the FINAL answer of a turn (closes the gap where the
# main loop names Sendbird APIs without any skill/agent involved — dogfood round 2).
#
# Behavior: if the final answer contains Sendbird-specific API identifiers AND code (or, in
# prose, a Sendbird error code or a dotted Sendbird symbol),
# but no citation marker, block ONCE with a reason (Claude continues and adds sources
# or corrects). The documented `stop_hook_active` guard makes the second pass exit 0,
# so this can never loop or trap the session. Fail-open on any parsing problem.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

# The reports of this session's agents that hooks/session-state.sh kept for the relay check below
reports="$(session_state_file agent-reports)"

# Documented loop guard: if we already blocked once this stop, let it pass.
if [ "$(jget '.stop_hook_active')" = "true" ]; then
  [ -z "$reports" ] || agent_pending || rm -f "$reports"
  exit 0
fi

text="$(final_answer_text)"
[ -n "$text" ] || exit 0

# A token the customer pasted in the request is a secret: the answer refers to it, never repeats it
# (docs/AGENT_CONTRACT.md section 3, hooks/welcome.sh). In a 2026-10 TC round the main session wrote a
# pasted test session token into its answer, which a non-interactive caller prints. The tokens are
# those of the latest request in the transcript and, because `claude -p --no-session-persistence`
# writes no transcript, those hooks/session-state.sh saved as hashes from this session's requests
# (hooks/lib/hook-helpers.sh request_tokens, text_repeats_request_token). A UUID (an App ID) is not a
# secret and does not count.
if text_repeats_request_token "$text"; then
  jq -n '{decision: "block",
    reason: "Final-answer secret check (Sendbird plugin): this answer repeats a token value the customer pasted in the request. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), and refer to that value only as \"the token you provided\" (in Korean, \"주신 토큰\"); never write the value or part of it, in the text, in code, or in a run summary."}'
  exit 0
fi

# docs/AGENT_CONTRACT.md section 6: when the answer relays an agent's result, it keeps the agent's check
# lines and its symbol/source table. In a 2026-10 TC round the main session turned a background agent's
# seven check lines and five-row source table into "the checks passed and the agent listed its sources".
# The agent's report comes from SubagentStop (hooks/session-state.sh); an answer that leaves out a check
# name or a source file of it is sent back once. An interim answer while an agent still runs is not
# checked; a relayed report is forgotten once an answer passes or after the one send-back.
if [ -n "$reports" ] && [ -s "$reports" ] && ! agent_pending; then
  missing_checks=""; missing_sources=""
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    printf '%s' "$text" | grep -Fqi -- "$name" || missing_checks="${missing_checks}${missing_checks:+, }$name"
  done < <(report_check_names < "$reports")
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    printf '%s' "$text" | grep -Fq -- "$file" || missing_sources="${missing_sources}${missing_sources:+, }$file"
  done < <(report_source_files < "$reports")
  if [ -n "$missing_checks$missing_sources" ]; then
    jq -n --arg c "$missing_checks" --arg s "$missing_sources" '{decision: "block",
      reason: ("Final-answer relay check (Sendbird plugin): the agent'\''s report has "
        + ([ (if $c != "" then "check lines this answer leaves out (" + $c + ")" else empty end),
             (if $s != "" then "symbol/source table rows whose sources this answer leaves out (" + $s + ")" else empty end) ] | join(" and "))
        + ". Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), and carry the agent'\''s Checks and Evidence sections as it wrote them: each check on its own line by its name with the result and file:line, and the symbol, source, version, and verification table with every row (docs/AGENT_CONTRACT.md section 6). Translate the wording if you answer in another language, but keep the check names, symbols, paths, lines, and versions exactly.")}'
    exit 0
  fi
  rm -f "$reports"
fi

# docs/AGENT_CONTRACT.md "Cite the curated entry": when this turn read a curated file and the answer
# cites a link but no curated path, the link stands in for the entry (often a community or source
# link the entry itself cites). Send it back once to cite the curated entry first.
if printf '%s' "$text" | grep -Eq 'https?://' \
  && ! printf '%s' "$text" | grep -Eq 'knowledge/curated/|(common|cross-cutting|products|hosts)/[A-Za-z0-9._-]+\.md' \
  && turn_tool_inputs | grep -Fq 'knowledge/curated/'; then
  jq -n '{decision: "block",
    reason: "Final-answer citation gate (Sendbird plugin): this turn read knowledge/curated files, but the answer cites only links. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check): cite the curated entry you used as knowledge/curated/<platform>/<path> with its heading or line, next to the fact it supports. A link that the entry cites (a public source file, a community case) may follow it but never replaces it, and cite a page only if you read it in this turn. Do not invent symbols."}'
  exit 0
fi

# A six-digit number counts as an error code only next to an error word on the same
# line; otherwise PR numbers, dates and IDs would gate unrelated answers.
code_ctx='(error|Error|ERROR|code|Code|에러|오류|코드)[^0-9]{0,24}[0-9]{6}([^0-9]|$)'

# A Sendbird type followed by a member (GroupChannel.createChannel) names an API even in prose.
dotted_symbol='(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)\.[A-Za-z_]'

# Gate Sendbird-flavored answers that include code-shaped content, and prose answers that name
# a Sendbird error code or a dotted Sendbird symbol ("Error code 400302 means ..." has no code
# block but states a fact that needs a source). A bare type name in prose is not checked.
printf '%s' "$text" | grep -Eq "SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|@sendbird/|\bSBU[A-Z]|\bSBA[A-Z]|\bSBDSK|$code_ctx" || exit 0
printf '%s' "$text" | grep -Eq '```|[A-Za-z]\([A-Za-z]*:' \
  || printf '%s' "$text" | grep -Eq "$code_ctx|$dotted_symbol" || exit 0

# Pass only when a concrete source marker resolves to a shipped local file or an
# allowed public URL. Vague words such as "verified" are not citations.
sources="$(printf '%s' "$text" | grep -Eo '(source:|출처:[[:space:]])[[:space:]]*[^)`[:space:]]+' | sed -E 's/^(source:|출처:)[[:space:]]*//' || true)"
symbols="$(printf '%s' "$text" | grep -Eo '(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)(\.[A-Za-z_][A-Za-z0-9_]*)?' | sort -u || true)"
instance_methods="$(printf '%s' "$text" | grep -Eo '(sb|channel|messengerLauncher)\.[A-Za-z_][A-Za-z0-9_]*' | sed 's/.*\.//' | sort -u || true)"
error_codes="$(printf '%s' "$text" | grep -Eo "$code_ctx" | grep -Eo '[0-9]{6}' | sort -u || true)"
symbols="$(printf '%s\n%s\n%s\n' "$symbols" "$instance_methods" "$error_codes" | sed '/^$/d' | sort -u)"
# Nothing checkable (for example a bare package name in prose): let it pass.
[ -n "$symbols" ] || exit 0
# Plugin files, the plugin's SDK cache, installed SDK interfaces, and public Sendbird pages
# (hooks/lib/hook-helpers.sh resolve_cited_sources); a file the model wrote in the app does not count.
resolve_cited_sources "$(jget '.cwd')" <<< "$sources"
all_symbols_sourced "$symbols" && exit 0

jq -n '{decision: "block",
  reason: "Final-answer citation gate (Sendbird plugin): this answer names Sendbird APIs/code but cites no source. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), citing a verifiable source per symbol — knowledge/curated/<platform>/... , the customer-local SDK surface or installed SDK files, a file in a public sendbird/* repo (a /blob/ or /raw/ link, not an issue or discussion), or a version-matched sendbird.com/docs page — or state: I do not know, and list what you checked. Do not invent symbols."}'
exit 0
