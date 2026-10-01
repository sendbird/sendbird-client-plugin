#!/usr/bin/env bash
# PreToolUse Write/Edit/MultiEdit: block Sendbird API code unless its cited source
# exists and contains the emitted symbol.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

tool="$(jget .tool_name)"
case "$tool" in
  Write) body="$(jget .tool_input.content)"; path="$(jget .tool_input.file_path)" ;;
  Edit) body="$(jget .tool_input.new_string)"; path="$(jget .tool_input.file_path)" ;;
  MultiEdit) body="$(printf '%s' "$HOOK_JSON" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)"; path="$(jget .tool_input.file_path)" ;;
  *) exit 0 ;;
esac
[ -n "$body" ] || exit 0

existing=""
[ "$tool" = "Write" ] || { [ -n "${path:-}" ] && [ -r "$path" ] && existing="$(cat "$path")"; }
context="${existing}${existing:+$'\n'}${body}"
symbols="$(printf '%s' "$body" | grep -Eo '(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)(\.[A-Za-z_][A-Za-z0-9_]*)?' | sort -u || true)"
if printf '%s' "$context" | grep -Eq '@sendbird/|sendbird-(calls|desk)|Sendbird(Chat|UIKit|Calls|Live|Desk)|AIAgentMessenger'; then
  instance_methods="$(printf '%s' "$body" | grep -Eo '(sb|channel|messengerLauncher)\.[A-Za-z_][A-Za-z0-9_]*' | sed 's/.*\.//' | sort -u || true)"
  symbols="$(printf '%s\n%s\n' "$symbols" "$instance_methods" | sed '/^$/d' | sort -u)"
fi
[ -n "$symbols" ] || exit 0

sources="$(printf '%s' "$context" | grep -Eo 'source:[[:space:]]*[^)`[:space:]]+' | sed -E 's/^source:[[:space:]]*//' | sort -u || true)"
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
    knowledge/curated/*)
      resolved_sources+=("${CLAUDE_PLUGIN_ROOT:-.}/$source") ;;
    .sendbird-client/cache/*)
      resolved_sources+=("${cwd:-$(pwd)}/$source") ;;
    *.swiftinterface|*.d.ts)
      resolved_sources+=("$source") ;;
    https://sendbird.com/docs/*|https://github.com/sendbird/*)
      tmp_source="$(mktemp)"
      if curl -fsSL --max-time 8 "$source" -o "$tmp_source" 2>/dev/null; then
        resolved_sources+=("$tmp_source")
        tmp_sources+=("$tmp_source")
      else
        rm -f "$tmp_source"
      fi
      ;;
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

jq -n '{hookSpecificOutput:{
  hookEventName:"PreToolUse",
  permissionDecision:"deny",
  permissionDecisionReason:"Sendbird API code requires a concrete source comment whose file or public URL contains the emitted symbol. Preserve the template source comment or cite knowledge/curated, the customer SDK cache, a version-matched public source, or stop if unverifiable."
}}'
