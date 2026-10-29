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
    reason: "Final-answer secret check (Sendbird Client plugin): this answer repeats a token value the customer pasted in the request. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), and refer to that value only as \"the token you provided\" (in Korean, \"주신 토큰\"); never write the value or part of it, in the text, in code, or in a run summary."}'
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
      reason: ("Final-answer relay check (Sendbird Client plugin): the agent'\''s report has "
        + ([ (if $c != "" then "check lines this answer leaves out (" + $c + ")" else empty end),
             (if $s != "" then "symbol/source table rows whose sources this answer leaves out (" + $s + ")" else empty end) ] | join(" and "))
        + ". Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), and carry the agent'\''s Checks and Evidence sections as it wrote them: each check on its own line by its name with the result and file:line, and the symbol, source, version, and verification table with every row (docs/AGENT_CONTRACT.md section 6). Translate the wording if you answer in another language, but keep the check names, symbols, paths, lines, and versions exactly.")}'
    exit 0
  fi
  rm -f "$reports"
fi

# skills/upgrade-sdk/SKILL.md steps 2 and 4, checked from what this turn did (hooks/session-state.sh keeps
# it per session, so this works without a transcript too). In five 2026-10 TC rounds the upgrade answer gave
# target versions without the latestInMajor, latest, and source values of latest-version.sh, and the plan
# was made without opening the curated files step 4 names. Only a turn that ran the skill and looked up a
# version is checked, and never an interim answer while an agent of the turn still runs.
if trace_has "skill upgrade-sdk" && trace_lines | grep -q '^latest ' && ! agent_pending; then
  up_problems=""
  missing_reads="$(upgrade_missing_reads "$(jget '.cwd')" | paste -sd ',' - | sed 's/,/, /g')"
  [ -z "$missing_reads" ] || up_problems="step 4 says to read ${missing_reads} before the plan, and this turn did not open them: read each one now (the Read tool, or cat in a shell), check the plan against its rules, and cite each rule you apply with its file and heading"
  missing_fields=""
  printf '%s' "$text" | grep -q 'latestInMajor' || missing_fields="latestInMajor"
  printf '%s' "$text" | grep -Eq '(^|[^A-Za-z])latest([^A-Za-z]|$)' || missing_fields="${missing_fields}${missing_fields:+, }latest"
  missing_src=""
  while read -r _ kind pkg; do
    [ -n "$pkg" ] || continue
    case "$kind" in
      npm) src="npm view $pkg versions" ;;
      spm) src="git ls-remote --tags $pkg" ;;
      maven) src="${pkg##*:}/maven-metadata.xml" ;;
      *) continue ;;
    esac
    printf '%s' "$text" | grep -Fq -- "$src" && continue
    # a lookup that failed is reported with its error instead of a source
    printf '%s' "$text" | grep -Fq -- "$pkg" && printf '%s' "$text" | grep -Eiq 'error|failed|could not|실패|오류' && continue
    missing_src="${missing_src}${missing_src:+; }$src"
  done < <(trace_lines | grep '^latest ' | awk '!seen[$0]++')
  if [ -n "$missing_fields$missing_src" ]; then
    q="step 2 says to quote latestInMajor, latest, and source from the output of tools/local-sdk/latest-version.sh for each package"
    [ -z "$missing_fields" ] || q="$q, and this answer does not name ${missing_fields}"
    [ -z "$missing_src" ] || q="$q, and it leaves out the source of ($missing_src)"
    q="$q: give each package's latestInMajor and latest values by those names, with the source exactly as the tool printed it (for a lookup that failed, its error instead)"
    up_problems="${up_problems}${up_problems:+; and }$q"
  fi
  if [ -n "$up_problems" ]; then
    jq -n --arg p "$up_problems" '{decision: "block",
      reason: ("Upgrade answer check (Sendbird Client plugin, skills/upgrade-sdk/SKILL.md): " + $p + ". Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), keeping its plan, its question, and its run summary as they are unless the rules you read change them. Do not change project files because of this check.")}'
    exit 0
  fi
fi

# docs/AGENT_CONTRACT.md section 3: whether the App ID is set comes only from tools/detection/resolve-app-id.sh,
# and only setup stops to ask for it (run-check too, whose preflight needs it to run the app). In a 2026-10
# Codex TC run, push-setup read an empty SENDBIRD_APP_ID in project.yml, asked for the App ID, and stopped
# with no change and no platform agent. A turn that ran another skill and ends with that question is sent
# back once.
skills_run="$(trace_lines | sed -n 's/^skill //p' | grep -v -- '-agent$' | awk '!seen[$0]++')"
if [ -n "$skills_run" ] && ! printf '%s\n' "$skills_run" | grep -Eqx 'setup|run-check' && answer_asks_app_id "$text"; then
  jq -n --arg s "$(printf '%s' "$skills_run" | paste -sd ',' - | sed 's/,/, /g')" '{decision: "block",
    reason: ("App ID check (Sendbird Client plugin): this turn ran " + $s + ", which does not need the App ID, and only setup stops to ask for it (docs/AGENT_CONTRACT.md section 3: whether it is set comes only from the from value of tools/detection/resolve-app-id.sh, never from reading project.yml, profile.json, or the environment). Do not ask for it and do not stop on it: continue the skill and hand the code to the platform agent as the skill says (in Codex, its launcher skill), so the app reads the App ID from its configuration at run time. When resolve-app-id.sh reports from missing, put setting the App ID under manualSteps. Then write the whole answer again as the reply itself (the user may see only this reply, so do not mention this check).")}'
  exit 0
fi

# A turn that only ran a Sendbird CLI plugin skill (its sendbird-setup choosing an app, then showing the SDK
# code of its own guide) is the CLI's work: the citation checks below are this plugin's rules, and sending
# such an answer back held up the CLI's app setup. A turn that also ran a skill of this or any other plugin,
# or none, is still checked.
if trace_lines | grep -q '^other-skill ' && ! trace_lines | grep -q '^skill '; then exit 0; fi

# docs/AGENT_CONTRACT.md "Cite the curated entry": when this turn read a curated file and the answer
# cites a link but no curated path, the link stands in for the entry (often a community or source
# link the entry itself cites). Send it back once to cite the curated entry first.
if printf '%s' "$text" | grep -Eq 'https?://' \
  && ! printf '%s' "$text" | grep -Eq 'knowledge/curated/|(common|cross-cutting|products|hosts)/[A-Za-z0-9._-]+\.md' \
  && turn_tool_inputs | grep -Fq 'knowledge/curated/'; then
  jq -n '{decision: "block",
    reason: "Final-answer citation gate (Sendbird Client plugin): this turn read knowledge/curated files, but the answer cites only links. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check): cite the curated entry you used as knowledge/curated/<platform>/<path> with its heading or line, next to the fact it supports. A link that the entry cites (a public source file, a community case) may follow it but never replaces it, and cite a page only if you read it in this turn. Do not invent symbols."}'
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
sources="$(cited_sources "$text" || true)"
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
  reason: "Final-answer citation gate (Sendbird Client plugin): this answer names Sendbird APIs/code but cites no source. Write the whole answer again as the reply itself (the user may see only this reply, so do not say it is repeated or mention this check), citing a verifiable source per symbol — knowledge/curated/<platform>/... , the customer-local SDK surface or installed SDK files, a file in a public sendbird/* repo (a /blob/ or /raw/ link, not an issue or discussion), or a version-matched sendbird.com/docs page — or state: I do not know, and list what you checked. Do not invent symbols."}'
exit 0
