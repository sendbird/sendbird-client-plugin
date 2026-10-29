#!/usr/bin/env bash
# PreToolUse Write/Edit/MultiEdit (Claude Code), apply_patch (Codex), and Bash commands that write
# a source file: block Sendbird API code unless its cited source exists and contains the emitted symbol,
# and block a JS/TS named import from a @sendbird path that the project's cached API surface says does
# not export that name (hooks/lib/js-import-paths.sh).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
# shellcheck source=lib/js-import-paths.sh
source "$HERE/lib/js-import-paths.sh"
read_stdin_json guard

cwd="$(jget '.cwd')"

# body_is_sourced <body> <existing file text>: 0 when every Sendbird symbol in <body> is found in a
# source that <body> or the existing file cites.
body_is_sourced() {
local body="$1" existing="$2" context symbols instance_methods sources
context="${existing}${existing:+$'\n'}${body}"
# A source comment names files, not API: its path (e.g. a framework folder) is not a symbol.
code="$(printf '%s' "$body" | grep -v 'source:' || true)"
symbols="$(printf '%s' "$code" | grep -Eo '(SendbirdChat|SendBirdCall|SendbirdCalls|AIAgentMessenger|SendbirdUIKit|SendbirdLive|SendbirdDesk|SendBirdDesk|MessengerLauncher|GroupChannel|BaseMessage|SBU[A-Z][A-Za-z0-9_]*|SBA[A-Z][A-Za-z0-9_]*|SBDSK[A-Za-z0-9_]*)(\.[A-Za-z_][A-Za-z0-9_]*)?' | grep -Ev '\.(xcframework|framework|swiftmodule|swiftinterface|swiftdoc|bundle)$' | sort -u || true)"
if printf '%s' "$context" | grep -Eq '@sendbird/|sendbird-(calls|desk)|Sendbird(Chat|UIKit|Calls|Live|Desk)|AIAgentMessenger'; then
  # The SDK instance under any name: sb, or a name the code types as the instance
  # ("sdk: SendbirdGroupChat", "chat: SendbirdChat"), so "sdk.groupChannel.getTotalUnreadMessageCount()"
  # is checked like "sb.groupChannel...". A shell-written file with that call and no source comment
  # was let through because only sb. counted (a 2026-10 TC run, Codex).
  typed="$(printf '%s' "$context" | grep -Eo '[A-Za-z_][A-Za-z0-9_]*[?!]?[[:space:]]*:[[:space:]]*Sendbird[A-Za-z]*' | sed -E 's/[?!]?[[:space:]]*:.*//' | grep -Ev '^(sb|channel|messengerLauncher)$' | sort -u | paste -sd '|' - || true)"
  prefixes="sb|channel|messengerLauncher${typed:+|$typed}"
  instance_methods="$(printf '%s' "$code" | grep -Eo "($prefixes)\.[A-Za-z_][A-Za-z0-9_]*" | sed 's/.*\.//' | sort -u || true)"
  # a call through a channel module (sb.groupChannel.createChannel, sdk.openChannel.getChannel)
  module_methods="$(printf '%s' "$code" | grep -Eo '\.(groupChannel|openChannel|feedChannel)\.[A-Za-z_][A-Za-z0-9_]*' | sed 's/.*\.//' | sort -u || true)"
  instance_methods="$(printf '%s\n%s\n' "$instance_methods" "$module_methods" | sed '/^$/d' | sort -u)"
  symbols="$(printf '%s\n%s\n' "$symbols" "$instance_methods" | sed '/^$/d' | sort -u)"
fi
[ -n "$symbols" ] || return 0

sources="$(printf '%s' "$context" | grep -Eo 'source:[[:space:]]*`?[^)`[:space:]]+' | sed -E 's/^source:[[:space:]]*`?//' | sort -u || true)"
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

# NOT_APPLIED ends every deny reason. A 2026-10 TC run: the agent added only the source comment after a
# denied Edit and never made the Edit again, so the app used a state variable it never declared.
NOT_APPLIED="This change was NOT applied: the file is unchanged. Fix what this message names (for example add the source: comment, in this change or in an edit before it), then make the same change again, and read the file to confirm it is there. If you cannot, say in the answer that this change is missing and fail the checks it affects; never report it as done."

# deny : the reason names the symbol no cited source contains, the cited sources that are not accepted as
# a source at all (UNRESOLVED_SOURCES, hooks/lib/hook-helpers.sh resolve_cited_sources), how to cite, and
# that the change must be made again (NOT_APPLIED)
deny() {
  local unresolved=""
  unresolved="$(printf '%s\n' ${UNRESOLVED_SOURCES[@]+"${UNRESOLVED_SOURCES[@]}"} | sed '/^$/d' | awk '!seen[$0]++' | head -5 | paste -sd ',' - | sed 's/,/, /g')"
  jq -n --arg sym "${UNSOURCED_SYMBOL:-}" --arg un "$unresolved" --arg na "$NOT_APPLIED" '{hookSpecificOutput:{
    hookEventName:"PreToolUse",
    permissionDecision:"deny",
    permissionDecisionReason:("Sendbird Client plugin: This change adds Sendbird code without a source from the Sendbird docs, so it wasn'\''t made. The code needs a source before it'\''s added.\n"
      + (if $sym != "" then "No cited source contains \($sym). " else "" end)
      + (if $un != "" then "Not accepted as a source: \($un). " else "" end)
      + "Sendbird API code requires a concrete source comment (source: <path or URL>) whose file or public URL contains the emitted symbol. Preserve the template source comment or cite knowledge/curated, the customer SDK cache or installed SDK files (node_modules/@sendbird, Pods, .build, SourcePackages, DerivedData), a version-matched sendbird.com/docs page or a file in a public sendbird/* repo (a /blob/ or /raw/ link, not an issue or discussion), or stop if unverifiable. Cite a plugin file by its path from the plugin root (knowledge/curated/<platform>/<file>.md) or by its absolute path inside the plugin folder; a file in the app, outside the installed SDK, does not count. " + $na)
  }}'
  exit 0
}

# check_import_paths <file path> <code> : deny when a named import in <code> uses a path the
# installed SDK does not export that name from
check_import_paths() {
  local reason
  reason="$(js_import_path_problem "$1" "$2" "$cwd")"
  [ -z "$reason" ] && return 0
  jq -n --arg r "$reason" --arg na "$NOT_APPLIED" '{hookSpecificOutput:{
    hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:($r + " " + $na)}}'
  exit 0
}

# Source files the symbol check covers. A package manifest or build setting (project.yml, Podfile,
# package.json, Info.plist, a Gradle script) names SDK packages, not API: the iOS Chat SDK package
# product name in project.yml read as a Chat SDK symbol, and the denied write left the app without
# its SDK package (a 2026-10 TC run).
src_ext='\.(swift|m|mm|kt|kts|java|ts|tsx|js|jsx|mjs|cjs|vue|svelte)\b'
# is_source_file <path> : 0 for a source file the symbol check covers. A .kts file is code, but a Gradle
# script names dependencies, not API, so build.gradle.kts and settings.gradle.kts are left out.
is_source_file() {
  case "$1" in *.gradle.kts) return 1 ;; esac
  printf '%s' "$1" | grep -Eq "${src_ext}\$"
}

tool="$(jget .tool_name)"
case "$tool" in
  Write)
    body="$(jget .tool_input.content)"
    check_import_paths "$(jget .tool_input.file_path)" "$body"
    is_source_file "$(jget .tool_input.file_path)" || exit 0
    if [ -n "$body" ] && ! body_is_sourced "$body" ""; then deny; fi ;;
  Edit|MultiEdit)
    if [ "$tool" = Edit ]; then body="$(jget .tool_input.new_string)"
    else body="$(printf '%s' "$HOOK_JSON" | jq -r '[.tool_input.edits[]?.new_string // empty] | join("\n")' 2>/dev/null)"; fi
    check_import_paths "$(jget .tool_input.file_path)" "$body"
    is_source_file "$(jget .tool_input.file_path)" || exit 0
    if [ -n "$body" ] && ! body_is_sourced "$body" "$(existing_text "$(jget .tool_input.file_path)")"; then deny; fi ;;
  apply_patch)
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      body="$(patch_added "$path")"
      [ -n "$body" ] || continue
      check_import_paths "$path" "$body"
      is_source_file "$path" || continue
      if patch_is_new "$path"; then existing=""; else existing="$(existing_text "$path")"; fi
      body_is_sourced "$body" "$existing" || deny
    done < <(patch_paths) ;;
  Bash)
    # A shell command that writes a source file carries the code in its text: a redirect or tee
    # (cat > F <<EOF, printf ... > F, tee F), an in-place edit (sed -i, perl -i), or a script that
    # writes files (open(..., 'w'), writeFile, write_text). Commands that only read files are not checked.
    # Codex may send the command as an argument list (["/bin/zsh", "-lc", "cat > f <<'EOF' ..."])
    cmd="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.command | if type == "array" then join(" ") else (. // "") end' 2>/dev/null)"
    targets="$(printf '%s' "$cmd" | grep -Eo '(>>?|tee([[:space:]]+-a)?)[[:space:]]*["'\'']?[^[:space:]"'\''<>|;&]+'"$src_ext" \
      | sed -E 's/^(>>?|tee([[:space:]]+-a)?)[[:space:]]*["'\'']?//' | sort -u || true)"
    if printf '%s' "$cmd" | grep -Eq '(^|[[:space:];&|])(sed|perl)[[:space:]]+(-[A-Za-z]*i|-i)|open\([^)]*["'\''][wa]\+?["'\'']|writeFile|appendFile|write_text|fs\.write'; then
      named="$(printf '%s' "$cmd" | grep -Eo '[^[:space:]"'\''<>|;&=(),]+'"$src_ext" | sort -u || true)"
      targets="$(printf '%s\n%s\n' "$targets" "$named" | sed '/^$/d' | sort -u)"
    fi
    [ -n "$targets" ] || exit 0
    while IFS= read -r path; do check_import_paths "$path" "$cmd"; done <<< "$targets"
    existing=""
    while IFS= read -r path; do existing="${existing}$(existing_text "$path")"$'\n'; done <<< "$targets"
    body_is_sourced "$cmd" "$existing" || deny ;;
esac
exit 0
