#!/usr/bin/env bash
# PreToolUse Write/Edit/MultiEdit (Claude Code), apply_patch (Codex), and Bash commands that write
# a source file: block Sendbird API code unless its cited source exists and contains the emitted symbol.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json guard

cwd="$(jget '.cwd')"

# body_is_sourced <body> <existing file text>: 0 when every Sendbird symbol in <body> is found in a
# source that <body> or the existing file cites.
body_is_sourced() {
local body="$1" existing="$2" context symbols instance_methods sources
context="${existing}${existing:+$'\n'}${body}"
symbols="$(printf '%s' "$body" | grep -Eo '(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)(\.[A-Za-z_][A-Za-z0-9_]*)?' | sort -u || true)"
if printf '%s' "$context" | grep -Eq '@sendbird/|sendbird-(calls|desk)|Sendbird(Chat|UIKit|Calls|Live|Desk)|AIAgentMessenger'; then
  instance_methods="$(printf '%s' "$body" | grep -Eo '(sb|channel|messengerLauncher)\.[A-Za-z_][A-Za-z0-9_]*' | sed 's/.*\.//' | sort -u || true)"
  symbols="$(printf '%s\n%s\n' "$symbols" "$instance_methods" | sed '/^$/d' | sort -u)"
fi
[ -n "$symbols" ] || return 0

sources="$(printf '%s' "$context" | grep -Eo 'source:[[:space:]]*[^)`[:space:]]+' | sed -E 's/^source:[[:space:]]*//' | sort -u || true)"
# Plugin files, the plugin's SDK cache, installed SDK interfaces, and public Sendbird pages
# (hooks/lib/hook-helpers.sh resolve_cited_sources); a file the model wrote in the app does not count.
resolve_cited_sources "$cwd" <<< "$sources"
all_symbols_sourced "$symbols"
}

# existing_text <path>: the file's current content; a relative path resolves from the session cwd
existing_text() {
  local p="$1"
  case "$p" in /*) ;; *) p="${cwd:-$(pwd)}/$p" ;; esac
  [ -r "$p" ] && cat "$p"
  return 0
}

deny() {
  jq -n '{hookSpecificOutput:{
    hookEventName:"PreToolUse",
    permissionDecision:"deny",
    permissionDecisionReason:"Sendbird API code requires a concrete source comment whose file or public URL contains the emitted symbol. Preserve the template source comment or cite knowledge/curated, the customer SDK cache or installed SDK files (node_modules/@sendbird, Pods, .build, SourcePackages, DerivedData), a version-matched sendbird.com/docs page or a file in a public sendbird/* repo (a /blob/ or /raw/ link, not an issue or discussion), or stop if unverifiable."
  }}'
  exit 0
}

tool="$(jget .tool_name)"
case "$tool" in
  Write)
    body="$(jget .tool_input.content)"
    if [ -n "$body" ] && ! body_is_sourced "$body" ""; then deny; fi ;;
  Edit|MultiEdit)
    if [ "$tool" = Edit ]; then body="$(jget .tool_input.new_string)"
    else body="$(printf '%s' "$HOOK_JSON" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)"; fi
    if [ -n "$body" ] && ! body_is_sourced "$body" "$(existing_text "$(jget .tool_input.file_path)")"; then deny; fi ;;
  apply_patch)
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      body="$(patch_added "$path")"
      [ -n "$body" ] || continue
      if patch_is_new "$path"; then existing=""; else existing="$(existing_text "$path")"; fi
      body_is_sourced "$body" "$existing" || deny
    done < <(patch_paths) ;;
  Bash)
    # A shell command that writes a source file carries the code in its text: a redirect or tee
    # (cat > F <<EOF, printf ... > F, tee F), an in-place edit (sed -i, perl -i), or a script that
    # writes files (open(..., 'w'), writeFile, write_text). Commands that only read files are not checked.
    cmd="$(jget .tool_input.command)"
    src_ext='\.(swift|m|mm|kt|kts|java|ts|tsx|js|jsx|mjs|cjs)\b'
    targets="$(printf '%s' "$cmd" | grep -Eo '(>>?|tee([[:space:]]+-a)?)[[:space:]]*["'\'']?[^[:space:]"'\''<>|;&]+'"$src_ext" \
      | sed -E 's/^(>>?|tee([[:space:]]+-a)?)[[:space:]]*["'\'']?//' | sort -u || true)"
    if printf '%s' "$cmd" | grep -Eq '(^|[[:space:];&|])(sed|perl)[[:space:]]+(-[A-Za-z]*i|-i)|open\([^)]*["'\''][wa]\+?["'\'']|writeFile|appendFile|write_text|fs\.write'; then
      named="$(printf '%s' "$cmd" | grep -Eo '[^[:space:]"'\''<>|;&=(),]+'"$src_ext" | sort -u || true)"
      targets="$(printf '%s\n%s\n' "$targets" "$named" | sed '/^$/d' | sort -u)"
    fi
    [ -n "$targets" ] || exit 0
    existing=""
    while IFS= read -r path; do existing="${existing}$(existing_text "$path")"$'\n'; done <<< "$targets"
    body_is_sourced "$cmd" "$existing" || deny ;;
esac
exit 0
