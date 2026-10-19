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

# Documented loop guard: if we already blocked once this stop, let it pass.
[ "$(jget '.stop_hook_active')" = "true" ] && exit 0

text="$(final_answer_text)"
[ -n "$text" ] || exit 0

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
