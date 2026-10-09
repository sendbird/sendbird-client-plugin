#!/usr/bin/env bash
# Stop hook: citation gate for the FINAL answer of a turn (closes the gap where the
# main loop names Sendbird APIs without any skill/agent involved — dogfood round 2).
#
# Behavior: if the final answer contains Sendbird-specific API identifiers AND code,
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

# The runtime passes the final answer as last_assistant_message. Older runtimes do not,
# so fall back to the transcript, reading only what follows the latest user prompt: the
# final message may not be flushed yet, and the previous turn's answer must not be gated
# in its place. Fail open when neither source yields text.
text="$(jget '.last_assistant_message')"
if [ -z "$text" ]; then
  tp="$(jget '.transcript_path')"
  [ -n "$tp" ] && [ -r "$tp" ] || exit 0
  text="$(jq -rs '
    [.[] | select(.type=="user" or .type=="assistant")] as $m
    | ([$m[] | .type=="user" and ((.message.content|type)=="string"
          or ((.message.content|type)=="array" and any(.message.content[]; .type!="tool_result")))]
       | indices(true) | last) as $u
    | if $u == null then empty else
        [$m[($u+1):][] | select(.type=="assistant") | (.message.content // [])
         | if type=="array" then map(select(.type=="text") | .text) | join("\n") else empty end
         | select(length>0)] | join("\n")
      end' "$tp" 2>/dev/null)"
fi
[ -n "$text" ] || exit 0

# A six-digit number counts as an error code only next to an error word on the same
# line; otherwise PR numbers, dates and IDs would gate unrelated answers.
code_ctx='(error|Error|ERROR|code|Code|에러|오류|코드)[^0-9]{0,24}[0-9]{6}([^0-9]|$)'

# Only gate Sendbird-flavored answers that include code-shaped content.
printf '%s' "$text" | grep -Eq "SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|@sendbird/|\bSBU[A-Z]|\bSBA[A-Z]|\bSBDSK|$code_ctx" || exit 0
printf '%s' "$text" | grep -Eq '```|[A-Za-z]\([A-Za-z]*:' || exit 0

# Pass only when a concrete source marker resolves to a shipped local file or an
# allowed public URL. Vague words such as "verified" are not citations.
sources="$(printf '%s' "$text" | grep -Eo '(source:|출처:[[:space:]])[[:space:]]*[^)`[:space:]]+' | sed -E 's/^(source:|출처:)[[:space:]]*//' || true)"
symbols="$(printf '%s' "$text" | grep -Eo '(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)(\.[A-Za-z_][A-Za-z0-9_]*)?' | sort -u || true)"
instance_methods="$(printf '%s' "$text" | grep -Eo '(sb|channel|messengerLauncher)\.[A-Za-z_][A-Za-z0-9_]*' | sed 's/.*\.//' | sort -u || true)"
error_codes="$(printf '%s' "$text" | grep -Eo "$code_ctx" | grep -Eo '[0-9]{6}' | sort -u || true)"
symbols="$(printf '%s\n%s\n%s\n' "$symbols" "$instance_methods" "$error_codes" | sed '/^$/d' | sort -u)"
# Nothing checkable (for example a bare package name in prose): let it pass.
[ -n "$symbols" ] || exit 0
source_supports_symbol() {
  local file="$1" symbol="$2" method
  [ -s "$file" ] || return 1
  grep -Fq -- "$symbol" "$file" && return 0
  method="${symbol#*.}"
  grep -Eq -- "(^|[^A-Za-z0-9_])${method}([^A-Za-z0-9_]|$)" "$file"
}
cwd="$(jget '.cwd')"
resolved_sources=()
tmp_sources=()
while IFS= read -r source; do
  [ -n "$source" ] || continue
  case "$source" in
    https://sendbird.com/docs/*|https://github.com/sendbird/*)
      tmp_source="$(mktemp)"
      if curl -fsSL --max-time 8 "$source" -o "$tmp_source" 2>/dev/null; then
        resolved_sources+=("$tmp_source")
        tmp_sources+=("$tmp_source")
      else
        rm -f "$tmp_source"
      fi
      ;;
    knowledge/curated/*)
      root="${CLAUDE_PLUGIN_ROOT:-.}"
      resolved_sources+=("$root/$source")
      ;;
    .sendbird-client/cache/*)
      project_root="${cwd:-$(pwd)}"
      resolved_sources+=("$project_root/$source")
      ;;
    *.swiftinterface|*.d.ts) resolved_sources+=("$source") ;;
  esac
done <<< "$sources"

valid=1
while IFS= read -r symbol; do
  supported=0
  for source_file in "${resolved_sources[@]}"; do
    if source_supports_symbol "$source_file" "$symbol"; then supported=1; break; fi
  done
  [ "$supported" -eq 1 ] || { valid=0; break; }
done <<< "$symbols"
for tmp_source in "${tmp_sources[@]}"; do rm -f "$tmp_source"; done
[ "$valid" -eq 1 ] && exit 0

jq -n '{decision: "block",
  reason: "Final-answer citation gate (Sendbird plugin): this answer names Sendbird APIs/code but cites no source. Re-emit it citing a verifiable source per symbol — knowledge/curated/<platform>/... , the customer-local SDK surface, a public sendbird/* repo, or a version-matched sendbird.com/docs page — or state: I do not know, and list what you checked. Do not invent symbols."}'
exit 0
