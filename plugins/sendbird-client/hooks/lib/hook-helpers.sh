#!/usr/bin/env bash
# Shared helpers for hook scripts. Source this file. Reads stdin JSON once.

# JQ_MISSING_REASON : what a guard tells the user when jq is missing (welcome.sh says it too)
JQ_MISSING_REASON='The Sendbird plugin safety checks (credential, source citation, and destructive-command guards) need jq, which is not on PATH, so this call was not checked. Approve it only if you trust it, and install jq to turn the checks back on.'

# ask_without_jq : the PreToolUse "ask" decision, built with printf because jq is absent
ask_without_jq() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$JQ_MISSING_REASON"
}

# read_stdin_json [guard] : caches the stdin payload into $HOOK_JSON (empty if none/not json).
# Every hook reads its input with jq. Without jq on PATH no check can run, so the hook stops
# here instead of reading '{}' and letting everything through: a PreToolUse guard (called with
# "guard") asks the user to approve the call, and any other hook exits 0 without blocking.
read_stdin_json() {
  if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null 2>&1 || true
    [ "${1:-}" = guard ] && ask_without_jq
    exit 0
  fi
  HOOK_JSON="$(cat 2>/dev/null || true)"
  if ! printf '%s' "$HOOK_JSON" | jq -e . >/dev/null 2>&1; then HOOK_JSON='{}'; fi
}

# is_noninteractive : 0 when SENDBIRD_NONINTERACTIVE turns on a non-interactive run (1, true, or
# yes in any case). Empty, 0, false, no, and any other value keep the run interactive. welcome.sh
# and run-summary-gate.sh both use this, so the model is told about the run summary exactly when
# the gate checks it. (tr, not ${v,,}: stock macOS bash 3.2.)
is_noninteractive() {
  case "$(printf '%s' "${SENDBIRD_NONINTERACTIVE:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes) return 0 ;;
    *) return 1 ;;
  esac
}

# jget <jq-path> : echo a string field from $HOOK_JSON ('' if absent)
jget() { printf '%s' "$HOOK_JSON" | jq -r "$1 // empty" 2>/dev/null; }

# final_answer_text : the text of the answer this Stop event ends. The runtime passes it as
# last_assistant_message; older runtimes do not, so fall back to the transcript and read only
# what follows the latest user prompt (the final message may not be flushed yet, and the
# previous turn's answer must not stand in for it). Prints nothing when neither yields text.
final_answer_text() {
  local text tp
  text="$(jget '.last_assistant_message')"
  if [ -z "$text" ]; then
    tp="$(jget '.transcript_path')"
    [ -n "$tp" ] && [ -r "$tp" ] || return 0
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
  printf '%s' "$text"
}

# --- Cited sources (source-claim-guard.sh, final-answer-gate.sh) ---------------------------
# A cited source counts only when the model cannot have written it in this session.

# public_source_url <url> : 0 for a page Sendbird controls: sendbird.com/docs, or a file at a
# ref in a sendbird GitHub repository (/blob/ or /raw/, or raw.githubusercontent.com). Issues,
# discussions, pull requests, and other GitHub pages are written by anyone, so they do not count.
public_source_url() {
  printf '%s' "$1" | grep -Eq '^https://sendbird\.com/docs/|^https://github\.com/sendbird/[A-Za-z0-9._-]+/(blob|raw)/[^[:space:]]+|^https://raw\.githubusercontent\.com/sendbird/[A-Za-z0-9._-]+/[^[:space:]]+'
}

# sdk_source_path <path> <cwd> : prints the real path of a local .d.ts or .swiftinterface when it
# is inside an installed SDK (node_modules/@sendbird or node_modules/sendbird-*, Pods, .build,
# SourcePackages, DerivedData, the Gradle cache) or the plugin's own knowledge/ or templates/;
# prints nothing for any other file, such as one the model just wrote in the app's folders.
# A relative path resolves from <cwd>; ".." is resolved before the check.
sdk_source_path() {
  local p="$1" cwd="$2" d real root
  case "$p" in /*) ;; *) p="${cwd:-$(pwd)}/$p" ;; esac
  [ -f "$p" ] || return 0
  d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 0
  real="$d/$(basename "$p")"
  root="$(cd "${CLAUDE_PLUGIN_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}" 2>/dev/null && pwd -P)"
  case "$real" in
    "$root"/knowledge/*|"$root"/templates/*) printf '%s' "$real" ;;
    */node_modules/@sendbird/*|*/node_modules/sendbird-*|*/Pods/*|*/.build/*|*/SourcePackages/*|*/DerivedData/*|*/.gradle/caches/*)
      printf '%s' "$real" ;;
  esac
}

# resolve_cited_sources <cwd> : reads cited source tokens on stdin, one per line, and fills
# RESOLVED_SOURCES with the files to search for a symbol: plugin files (knowledge/, templates/),
# the plugin's cache of the customer's installed SDK, installed SDK interfaces, and fetched
# copies of public pages. Fetched copies are also in TMP_SOURCES; remove them when done.
resolve_cited_sources() {
  local cwd="$1" source tmp_source local_path root="${CLAUDE_PLUGIN_ROOT:-.}"
  RESOLVED_SOURCES=(); TMP_SOURCES=()
  while IFS= read -r source; do
    source="${source//\`/}"   # a path written in backticks
    # a line or range after the file (chat.md:42, chat.md:42-60) still names that file
    [[ "$source" =~ ^(.*[^0-9:]):[0-9]+(-[0-9]+)?$ ]] && source="${BASH_REMATCH[1]}"
    [ -n "$source" ] || continue
    case "$source" in *..*) continue ;; esac
    case "$source" in
      knowledge/*|templates/*)
        RESOLVED_SOURCES+=("$root/$source") ;;
      .sendbird-client/cache/*)
        RESOLVED_SOURCES+=("${cwd:-$(pwd)}/$source") ;;
      *.swiftinterface|*.d.ts)
        local_path="$(sdk_source_path "$source" "$cwd")"
        [ -z "$local_path" ] || RESOLVED_SOURCES+=("$local_path") ;;
      https://*)
        public_source_url "$source" || continue
        tmp_source="$(mktemp)"
        if curl -fsSL --max-time 8 "$source" -o "$tmp_source" 2>/dev/null; then
          RESOLVED_SOURCES+=("$tmp_source"); TMP_SOURCES+=("$tmp_source")
        else
          rm -f "$tmp_source"
        fi ;;
    esac
  done
}

# source_supports_symbol <file> <symbol> : 0 when the file names the symbol, or for Type.member
# the member as a whole word
source_supports_symbol() {
  local file="$1" symbol="$2" method
  [ -s "$file" ] || return 1
  grep -Fq -- "$symbol" "$file" && return 0
  method="${symbol#*.}"
  grep -Eq -- "(^|[^A-Za-z0-9_])${method}([^A-Za-z0-9_]|$)" "$file"
}

# all_symbols_sourced <symbols> : 0 when every symbol (one per line) is in one of
# RESOLVED_SOURCES. Removes the fetched copies either way.
all_symbols_sourced() {   # sets UNSOURCED_SYMBOL to the first symbol no source contains
  local symbol supported source_file valid=1
  while IFS= read -r symbol; do
    [ -n "$symbol" ] || continue
    supported=0
    for source_file in ${RESOLVED_SOURCES[@]+"${RESOLVED_SOURCES[@]}"}; do
      if source_supports_symbol "$source_file" "$symbol"; then supported=1; break; fi
    done
    [ "$supported" -eq 1 ] || { valid=0; UNSOURCED_SYMBOL="$symbol"; break; }
  done <<< "$1"
  for source_file in ${TMP_SOURCES[@]+"${TMP_SOURCES[@]}"}; do rm -f "$source_file"; done
  [ "$valid" -eq 1 ]
}

# emit_warning <text> : warn-only output (exit 0 in caller). Never blocks.
emit_warning() { jq -n --arg m "$1" '{systemMessage: $m}'; }

# telemetry_enabled : 0 if opt-in flag is true (env TELEMETRY_OPT_IN or config/plugin-config.json)
telemetry_enabled() {
  [ "${TELEMETRY_OPT_IN:-}" = "true" ] && return 0
  local cfg="${CLAUDE_PLUGIN_ROOT:-.}/config/plugin-config.json"
  [ -f "$cfg" ] || cfg="config/plugin-config.json"
  if [ -f "$cfg" ]; then
    [ "$(jq -r '.telemetry.enabled // false' "$cfg" 2>/dev/null)" = "true" ] && return 0
  fi
  return 1
}

# telemetry_log_path : where the JSONL lives (override with TELEMETRY_LOG for tests)
telemetry_log_path() { printf '%s' "${TELEMETRY_LOG:-$HOME/.claude/sendbird-client-telemetry.jsonl}"; }

# Codex reports no duration for a subagent, so the start hook keeps the start time per agent_id.
# now_ms : the current time in milliseconds (whole seconds where perl is missing)
now_ms() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || printf '%s000' "$(date +%s)"; }
# agent_start_mark <agent_id> : the file that holds that subagent's start time, in the plugin data
# folder Codex passes to hooks (PLUGIN_DATA) or the temp folder
agent_start_mark() { printf '%s/agent-start-%s' "${PLUGIN_DATA:-${TMPDIR:-/tmp}}" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9_-' _)"; }

# Codex edits files with apply_patch: tool_name "apply_patch", tool_input.command holding
#   *** Begin Patch
#   *** Add File: <path> | *** Update File: <path> (optionally *** Move to: <path>) | *** Delete File: <path>
#   +added line / -removed line / context line
#   *** End Patch
# patch_paths : the files the patch adds or updates, one per line (a moved file under its new path)
patch_paths() {
  jget '.tool_input.command' | awk '
    /^\*\*\* (Add|Update) File: / { p = $0; sub(/^\*\*\* (Add|Update) File: /, "", p); print p; next }
    /^\*\*\* Move to: / { p = $0; sub(/^\*\*\* Move to: /, "", p); print p }' | awk '!seen[$0]++'
}
# patch_is_new <path> : 0 when the patch creates <path> (Add File)
patch_is_new() {
  jget '.tool_input.command' | grep -Fxq -- "*** Add File: $1"
}
# patch_added [<path>] : the lines the patch adds (without the leading +), for one file or for all
patch_added() {
  jget '.tool_input.command' | awk -v want="${1:-}" '
    /^\*\*\* (Add|Update|Delete) File: / { cur = $0; sub(/^\*\*\* (Add|Update|Delete) File: /, "", cur); next }
    /^\*\*\* Move to: / { cur = $0; sub(/^\*\*\* Move to: /, "", cur); next }
    /^\*\*\* / { next }
    /^\+/ { if (want == "" || cur == want) print substr($0, 2) }'
}
