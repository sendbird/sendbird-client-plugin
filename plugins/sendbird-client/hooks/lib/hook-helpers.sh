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

# turn_tool_inputs : the input of each tool call made since the latest user prompt, one per line,
# read from transcript_path. Claude Code transcripts keep a call as a tool_use item of an assistant
# message; Codex rollouts keep it as a response_item (function_call arguments, custom_tool_call
# input, local_shell_call action). Tool results are not included. Prints nothing without a
# readable transcript.
turn_tool_inputs() {
  local tp
  tp="$(jget '.transcript_path')"
  [ -n "$tp" ] && [ -r "$tp" ] || return 0
  jq -rs '
    def claude_prompt: .type=="user" and ((.message.content|type)=="string"
      or ((.message.content|type)=="array" and any(.message.content[]; .type!="tool_result")));
    def codex_prompt: .type=="response_item" and .payload.type=="message" and .payload.role=="user";
    ([to_entries[] | select(.value | claude_prompt or codex_prompt) | .key] | last // -1) as $u
    | .[($u+1):][]
    | if .type=="assistant" then
        (.message.content // []) | if type=="array" then .[] | select(.type=="tool_use") | .input | tojson else empty end
      elif .type=="response_item" and (.payload.type | IN("function_call", "custom_tool_call", "local_shell_call")) then
        .payload | (.arguments // .input // .action) | if type=="string" then . else tojson end
      else empty end' "$tp" 2>/dev/null
}

# The customer's own request, read from transcript_path. In a Claude Code transcript a user message is
# also a skill's text (isMeta), a Stop hook's feedback (isMeta), or the notice that a background agent
# finished (origin.kind "task-notification", text "<task-notification>..."); none of these is the
# request, and the turn the request started goes on across them. In a Codex rollout the request is a
# response_item message with role user; the session's own context items (<environment_context>,
# <user_instructions>) are user messages too and are skipped.
# REQUEST_JQ_DEFS : the jq definitions both helpers below use
REQUEST_JQ_DEFS='
  def text_of: if type=="string" then . elif type=="array" then map(if type=="object" then (.text // "") elif type=="string" then . else "" end) | join("\n") else "" end;
  def claude_request: .type=="user" and (.isMeta != true) and ((.origin.kind // "") != "task-notification")
    and ((.message.content|type)=="string" or ((.message.content|type)=="array" and any(.message.content[]; .type!="tool_result")))
    and ((.message.content | text_of | startswith("<task-notification>")) | not);
  def codex_request: .type=="response_item" and .payload.type=="message" and .payload.role=="user"
    and ((.payload.content | text_of | test("^\\s*<[a-z_]+>")) | not);
  def request_text: if .type=="user" then (.message.content | text_of) else (.payload.content | text_of) end;
  def last_request_index: [to_entries[] | select(.value | claude_request or codex_request) | .key] | last // -1;'

# turn_user_prompt : the text of the latest request (see above). Prints nothing without a readable
# transcript or a request.
turn_user_prompt() {
  local tp
  tp="$(jget '.transcript_path')"
  [ -n "$tp" ] && [ -r "$tp" ] || return 0
  jq -rs "$REQUEST_JQ_DEFS"'
    last_request_index as $u | if $u < 0 then empty else .[$u] | request_text end' "$tp" 2>/dev/null
}

# agent_pending : 0 when a subagent started since the latest request has not handed its result back
# yet, so the answer this Stop ends is an interim one while the agent runs. Claude Code: an Agent (or
# Task) call whose tool_result is "Async agent launched ..." (or missing) and whose
# <task-notification> (it names the call as <tool-use-id>ID</tool-use-id>) has not arrived. Codex: a
# spawn_agent call (its output names the agent, {"task_name": "/root/<name>"}) with no agent_message
# "Message Type: FINAL_ANSWER" from that agent ("Sender: /root/<name>") after it.
# Claude Code also lists the tasks still in flight in the Stop input (background_tasks, an entry per
# task with type "subagent" and status "running" for an agent); when that list is there it decides.
# Without it and without a readable transcript (claude -p --no-session-persistence writes no session
# file), the agents hooks/session-state.sh saw start and not yet stop in this session count. With none of
# these, no agent counts as pending, so the caller checks the answer as before.
agent_pending() {
  local tp n bt
  bt="$(printf '%s' "$HOOK_JSON" | jq -r 'if (.background_tasks | type) == "array"
    then [.background_tasks[] | select(type == "object" and .type == "subagent" and .status == "running")] | length
    else "none" end' 2>/dev/null)"
  case "$bt" in
    0) return 1 ;;
    ''|none) ;;
    *) return 0 ;;
  esac
  tp="$(jget '.transcript_path')"
  [ -n "$tp" ] && [ -r "$tp" ] || { agents_running; return; }
  n="$(jq -rs "$REQUEST_JQ_DEFS"'
    .[(last_request_index + 1):] as $t
    | [ $t[] | select(.type=="assistant") | (.message.content // []) | if type=="array" then .[] else empty end
        | select(type=="object" and .type=="tool_use" and (.name | IN("Agent", "Task"))) | .id ] as $calls
    | [ $t[] | select(.type=="user") | (.message.content // []) | if type=="array" then .[] else empty end
        | select(type=="object" and .type=="tool_result") | {id: .tool_use_id, text: (.content | text_of)} ] as $results
    | ([ $t[] | select(.type=="user") | (.message.content | text_of) ] | join("\n")) as $user_text
    | [ $calls[] as $id
        | ([ $results[] | select(.id == $id) ] | first) as $r
        | select($r == null or ($r.text | startswith("Async agent launched")))
        | select($user_text | contains("<tool-use-id>" + $id + "</tool-use-id>") | not) | $id ] as $claude
    | [ $t[] | select(.type=="response_item" and .payload.type=="function_call" and .payload.name=="spawn_agent") | .payload.call_id ] as $spawns
    | [ $t[] | select(.type=="response_item" and (.payload.type | IN("function_call_output", "custom_tool_call_output")))
        | {id: .payload.call_id, out: (.payload.output | text_of)} ] as $outs
    | [ $t[] | select(.type=="response_item" and .payload.type=="agent_message") | (.payload.content | text_of)
        | select(contains("Message Type: FINAL_ANSWER")) ] as $finals
    | [ $spawns[] as $c
        | (([ $outs[] | select(.id == $c) ] | first // {out: ""}).out | (try (fromjson | .task_name // "") catch "")) as $name
        | select(if $name == "" then ($finals | length) == 0 else (any($finals[]; contains("Sender: " + $name + "\n")) | not) end) | $c ] as $codex
    | ($claude | length) + ($codex | length)' "$tp" 2>/dev/null)"
  [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null
}

# --- Cited sources (source-claim-guard.sh, final-answer-gate.sh) ---------------------------
# A cited source counts only when the model cannot have written it in this session.

# public_source_url <url> : 0 for a page Sendbird controls: sendbird.com/docs, or a file at a
# ref in a sendbird GitHub repository (/blob/ or /raw/, or raw.githubusercontent.com). Issues,
# discussions, pull requests, and other GitHub pages are written by anyone, so they do not count.
public_source_url() {
  printf '%s' "$1" | grep -Eq '^https://sendbird\.com/docs/|^https://github\.com/sendbird/[A-Za-z0-9._-]+/(blob|raw)/[^[:space:]]+|^https://raw\.githubusercontent\.com/sendbird/[A-Za-z0-9._-]+/[^[:space:]]+'
}

# plugin_root_real : the plugin root with symlinks resolved (CLAUDE_PLUGIN_ROOT, else this file's plugin)
plugin_root_real() { (cd "${CLAUDE_PLUGIN_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}" 2>/dev/null && pwd -P); }

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
  root="$(plugin_root_real)"
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
# A plugin file may be cited relative to the plugin root (knowledge/curated/ios/products/chat.md) or by
# its absolute path inside the plugin folder: Codex agents are told to write the plugin root as an
# absolute path (codex/agent-launcher.md), so their source comments carry it too. Punctuation that ends
# the sentence or list after a path (chat.md, chat.md:42.) is not part of it. A cited source that names
# no file or page this accepts is added to UNRESOLVED_SOURCES, for the deny message.
resolve_cited_sources() {
  local cwd="$1" source tmp_source local_path root="${CLAUDE_PLUGIN_ROOT:-.}" real_root
  real_root="$(plugin_root_real)"
  RESOLVED_SOURCES=(); TMP_SOURCES=(); UNRESOLVED_SOURCES=()
  while IFS= read -r source; do
    source="${source//\`/}"   # a path written in backticks
    # punctuation after the path: a comma or semicolon in a list, the period that ends a sentence
    while :; do case "$source" in *[,\;.:\'\"\]]) source="${source%?}" ;; *) break ;; esac; done
    # a line or range after the file (chat.md:42, chat.md:42-60, chat.md:42,50) still names that file
    [[ "$source" =~ ^(.*[^0-9:]):[0-9]+([,-][0-9]+)*$ ]] && source="${BASH_REMATCH[1]}"
    [ -n "$source" ] || continue
    case "$source" in *..*) UNRESOLVED_SOURCES+=("$source"); continue ;; esac
    case "$source" in
      knowledge/*|templates/*)
        RESOLVED_SOURCES+=("$root/$source") ;;
      .sendbird-client/cache/*)
        RESOLVED_SOURCES+=("${cwd:-$(pwd)}/$source") ;;
      /*|*.swiftinterface|*.d.ts)
        local_path="$(sdk_source_path "$source" "$cwd")"
        # an absolute path counts for a plugin file (knowledge/, templates/) or an installed SDK interface
        case "$source" in
          *.swiftinterface|*.d.ts) ;;
          *) case "$local_path" in "$real_root"/*) ;; *) local_path="" ;; esac ;;
        esac
        if [ -n "$local_path" ]; then RESOLVED_SOURCES+=("$local_path"); else UNRESOLVED_SOURCES+=("$source"); fi ;;
      https://*)
        public_source_url "$source" || { UNRESOLVED_SOURCES+=("$source"); continue; }
        tmp_source="$(mktemp)"
        if curl -fsSL --max-time 8 "$source" -o "$tmp_source" 2>/dev/null; then
          RESOLVED_SOURCES+=("$tmp_source"); TMP_SOURCES+=("$tmp_source")
        else
          rm -f "$tmp_source"; UNRESOLVED_SOURCES+=("$source")
        fi ;;
      *) UNRESOLVED_SOURCES+=("$source") ;;
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

# --- Per-session state (hooks/session-state.sh writes it; the gates and guards read it) ------------
# The transcript is not always there: `claude -p --no-session-persistence` writes no session file, so a
# check that reads only transcript_path skips itself. These files keep what the checks need per
# session_id (Claude Code and Codex both send it) in the plugin data folder (CLAUDE_PLUGIN_DATA in
# Claude Code, PLUGIN_DATA in Codex) or the temp folder.

# prompt_asks_build <text> : 0 when a request asks to build, compile, or type-check the project, or
# brings a build error ("fix this build error", "빌드해 줘", "run the typecheck"). "Build a chat screen"
# (build = make) is not a build request.
prompt_asks_build() {
  printf '%s' "$1" | grep -Eiq '\b(type-?check(s|ed|ing)?|tsc|xcodebuild|gradlew|assemble(debug|release)|compil(e|es|ed|ing|er))\b|\b(run|do|try|start|kick off)[[:space:]]+(a[[:space:]]+|the[[:space:]]+|an?[[:space:]]+)?(build|typecheck)\b|\bbuild[[:space:]]+(it|and[[:space:]]+(run|launch|test)|(the|my|this|your|our)[[:space:]]+(app|project|code|ios app|android app|web app))\b|\b(build|bundler|gradle|xcode|metro|webpack|vite)[[:space:]]+(error|errors|fails?|failed|failure|failing|log|output)\b|빌드|컴파일|타입[[:space:]]*체크|타입[[:space:]]*검사'
}

# session_state_file <kind> : this session's file of that kind; prints nothing without a session_id
session_state_file() {
  local sid
  sid="$(printf '%s' "$(jget '.session_id')" | tr -c 'A-Za-z0-9_-' _)"
  [ -n "$sid" ] || return 0
  printf '%s/%s-%s' "${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${TMPDIR:-/tmp}}}" "$1" "$sid"
}

# agents_running : 0 when an agent that started in this session (SubagentStart) has not stopped yet
# (SubagentStop). A start older than two hours is ignored, so an agent whose stop never arrived does
# not turn the checks off for the rest of the session.
agents_running() {
  local f
  f="$(session_state_file agents-running)"
  [ -n "$f" ] && [ -s "$f" ] || return 1
  awk -v now="$(date +%s)" -F'\t' '$1 != "" && $2 ~ /^[0-9]+$/ && now - $2 < 7200 { n++ } END { exit (n > 0 ? 0 : 1) }' "$f"
}

# A token the customer pasted is a secret: a run of 24 or more letters, digits, _ and - with a letter and
# a digit in it, written within 60 characters after a word such as token, secret, session, API key, or
# 토큰, or a JWT anywhere in the request. A UUID (an App ID) is not a secret and does not count.
# Not a token either (a 2026-10 dev session was blocked twice for repeating its own scratchpad path):
# - a part of a file path or a URL path: a run right after or before / or \, or followed by a file
#   extension (".log"), such as the "-Users-<name>-...-sendbird-plugin" folder of a Claude Code session;
# - a run that holds a UUID, such as a session ID folder ("<uuid>_old") or an artifact ID;
# - 키 inside a longer Korean word: "패키지" (package) is not "키" (key), so 키 counts only when no Hangul
#   syllable comes right before it.
# request_tokens <text> : the tokens in that text, one per line
request_tokens() {
  jq -rn --arg req "$1" '
    [ ($req | match("(?i)(token|secret|session|api[ _-]?key|password|bearer|credential|토큰|시크릿|비밀|세션|(?<![가-힣])키)[^\\n]{0,60}?(?<![A-Za-z0-9_/\\\\-])([A-Za-z0-9_-]{24,})(?![A-Za-z0-9_/\\\\-]|\\.[A-Za-z0-9])"; "g") | .captures[1].string),
      ($req | match("eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{5,}\\.[A-Za-z0-9_-]{5,}"; "g") | .string) ]
    | map(select(test("[A-Za-z]") and test("[0-9]")
        and (test("[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}") | not)))
    | unique | .[]' 2>/dev/null
}

# sha256_hex : the SHA-256 of stdin in hex, with whichever tool the machine has (nothing when none)
sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 | sed 's/^.*= *//'
  else cat >/dev/null; fi
}

# text_has_saved_token <text> : 0 when the text holds a token whose hash hooks/session-state.sh saved from
# a request of this session ("<length> <sha256>" per line; the token itself is never written). Every
# stretch of the text as long as a saved token is hashed, so a token inside a longer word counts too.
# Without perl's Digest::SHA only whole words (and JWTs) are compared.
text_has_saved_token() {
  local f cand h
  f="$(session_state_file request-tokens)"
  [ -n "$f" ] && [ -s "$f" ] || return 1
  if perl -MDigest::SHA -e 1 >/dev/null 2>&1; then
    printf '%s' "$1" | perl -MDigest::SHA=sha256_hex -e '
      open(my $fh, "<", $ARGV[0]) or exit 1;
      my (%want, %len);
      while (<$fh>) { chomp; my ($l, $h) = split / /; next unless $h && $l =~ /^\d+$/; $want{$h} = 1; $len{$l} = 1; }
      local $/; my $t = <STDIN>; $t = "" unless defined $t;
      for my $run ($t =~ /[A-Za-z0-9_.-]{24,}/g) {
        for my $l (keys %len) {
          next if $l > length $run;
          for my $i (0 .. length($run) - $l) { exit 0 if $want{ sha256_hex(substr($run, $i, $l)) }; }
        }
      }
      exit 1' "$f"
    return
  fi
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    h="$(printf '%s' "$cand" | sha256_hex)"
    [ -n "$h" ] && grep -q " $h\$" "$f" && return 0
  done < <(printf '%s' "$1" | grep -Eo 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}|[A-Za-z0-9_-]{24,}' | head -500)
  return 1
}

# text_repeats_request_token <text> : 0 when the text repeats a token the customer pasted: one in the
# latest request read from the transcript, or one saved from a request of this session
text_repeats_request_token() {
  local req t
  req="$(turn_user_prompt)"
  if [ -n "$req" ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      case "$1" in *"$t"*) return 0 ;; esac
    done < <(request_tokens "$req")
  fi
  text_has_saved_token "$1"
}

# An agent's report carries its checks, one per line by name with the result (docs/AGENT_CONTRACT.md
# section 4: "- init-once: pass ...", or a table row "| init-once | pass |"), and a symbol-to-source table
# (section 6: a header with symbol and source columns). The main session must relay both as written.
# report_check_names : the check names in the report on stdin, one per line, lower case
report_check_names() {
  jq -rR '(capture("^\\s*(?:[-*]|[0-9]+\\.)\\s+\\**`?(?<n>[a-z][a-z0-9-]*)`?\\**\\s*[:—–-]\\s*\\**(?:pass|fail|not run|not applicable|n/a|skipped)"; "i")
      // capture("^\\s*\\|\\s*\\**`?(?<n>[a-z][a-z0-9-]*)`?\\**\\s*\\|\\s*\\**(?:pass|fail|not run|not applicable|n/a|skipped)"; "i"))
    | .n | ascii_downcase' 2>/dev/null | awk '!seen[$0]++'
}
# report_source_files : the file (or page) name of each source cell of the report's symbol/source table
# on stdin, one per line, without the folder and the line (types.d.ts for node_modules/.../types.d.ts:52)
report_source_files() {
  awk -F'|' '
    /^[[:space:]]*\|/ {
      if (col == 0) {
        s = 0; y = 0
        for (i = 2; i < NF; i++) { c = tolower($i); gsub(/[[:space:]`*]/, "", c); if (c == "source") s = i; if (c == "symbol") y = i }
        if (s && y) col = s
        next
      }
      if ($0 ~ /^[[:space:]]*\|[-:|[:space:]]+$/) next
      v = $col; gsub(/`/, "", v); sub(/^[[:space:]]+/, "", v); sub(/[[:space:]].*$/, "", v)
      sub(/:[0-9][0-9,-]*$/, "", v); sub(/\/+$/, "", v); n = split(v, p, "/"); v = p[n]
      if (v ~ /[A-Za-z]/) print v
      next
    }
    { col = 0 }' | awk '!seen[$0]++'
}

# --- What this turn did (hooks/session-state.sh writes it on PreToolUse, and starts it again on each
# request) ----------------------------------------------------------------------------------------
# turn-trace-<session_id> holds one line per fact, so a gate can check a skill's steps without a transcript:
#   skill <name>                       a skill the turn started: the Skill tool, a shell read of
#                                      skills/<name>/SKILL.md (Codex), or a request that starts with
#                                      /<plugin>:<name> or $<plugin>:<name>
#   read knowledge/curated/<path>.md   a curated file the turn read: the Read tool, or a shell command
#                                      that reads it (cat, sed, head, grep, and the like)
#   latest <npm|spm|maven> <name>      a tools/local-sdk/latest-version.sh lookup
# trace_lines : this turn's trace (nothing without a session_id or a trace)
trace_lines() {
  local f
  f="$(session_state_file turn-trace)"
  [ -n "$f" ] && [ -r "$f" ] && cat "$f"
  return 0
}
# trace_has <line> : 0 when this turn's trace has that exact line
trace_has() { trace_lines | grep -Fxq -- "$1"; }
# curated_paths : the knowledge/curated/**/*.md paths named in the text on stdin, one per line
curated_paths() { grep -Eo 'knowledge/curated/[A-Za-z0-9_./-]+\.md' | awk '!seen[$0]++'; }
# latest_calls : one "latest <kind> <name>" line per latest-version.sh call in the command on stdin
latest_calls() {
  tr "\"'" '  ' | grep -Eo 'latest-version\.sh[[:space:]]+(npm|spm|maven)[[:space:]]+[^[:space:];|&)]+' \
    | awk '{ print "latest", $2, $3 }' | awk '!seen[$0]++'
}

# upgrade_missing_reads <project-dir> : the curated files skills/upgrade-sdk/SKILL.md step 4 says to read
# before the plan (knowledge/curated/<platform>/setup.md, hosts/<host>.md, and products/uikit.md when
# UIKit is installed) that this turn did not read, one per line. The platform, host, and products come
# from the profile tools/detection/detect.sh wrote in the project; without one, or for a file the plugin
# does not ship (a hybrid host), nothing is printed.
upgrade_missing_reads() {
  local root sd prof plat host f files
  root="${CLAUDE_PLUGIN_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}"
  sd="$(jq -r '.stateDir // empty' "$root/config/plugin-config.json" 2>/dev/null)"
  [ -n "$sd" ] && [ -n "${1:-}" ] || return 0
  prof="$1/$sd/profile.json"
  [ -r "$prof" ] || return 0
  plat="$(jq -r '.platform // empty' "$prof" 2>/dev/null)"
  host="$(jq -r '.host // empty' "$prof" 2>/dev/null)"
  case "$plat" in ios|android|js) ;; *) return 0 ;; esac
  files="setup.md"
  [ -n "$host" ] && files="$files hosts/$host.md"
  jq -e '(.products // []) | index("uikit")' "$prof" >/dev/null 2>&1 && files="$files products/uikit.md"
  for f in $files; do
    [ -f "$root/knowledge/curated/$plat/$f" ] || continue
    trace_has "read knowledge/curated/$plat/$f" || printf '%s\n' "knowledge/curated/$plat/$f"
  done
}

# --- Destructive CLI commands confirmed in the next prompt (destructive-command-guard.sh, session-state.sh)
# destructive_targets <part> : what a Sendbird CLI delete, revoke, or deactivate acts on, one per line: the
# words after the action that are not options (--id, -y), not the values of context options (--profile,
# --org-id, --app-id, --region, --env, --output, --format), and not shell variables. "sendbird --profile
# prod --app-id $APP chat user delete --id u-01 --yes" gives u-01.
destructive_targets() {
  printf '%s\n' "$1" | awk '{
    on = 0; skip = 0
    for (i = 1; i <= NF; i++) {
      w = $i
      if (!on) { if (w ~ /^(delete|revoke|deactivate)$/) on = 1; continue }
      if (skip) { skip = 0; continue }
      if (w ~ /^--(profile|org-id|app-id|region|env|output|format)$/) { skip = 1; continue }
      if (w ~ /^-/ || w ~ /^\$/ || w ~ /=/) continue
      print w
    }
  }' | awk 'NF && !seen[$0]++'
}
# prompt_confirms <text> : 0 when the text says yes to a pending action and does not say no
prompt_confirms() {
  printf '%s' "$1" | grep -Eiq "(^|[^a-z])(no|not|don'?t|do not|never|cancel|stop|wait)([^a-z]|$)|아니|하지 ?마|말아|취소|멈춰|중단|잠깐" && return 1
  printf '%s' "$1" | grep -Eiq '(^|[^a-z])(yes|yep|confirm(ed)?|approved?|go ahead|proceed|do it|delete (it|them)|ok(ay)?)([^a-z]|$)|네|예|응|좋아|확인|승인|진행|지워|삭제해|해 ?줘|해도 ?(돼|좋아)'
}
