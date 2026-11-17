#!/usr/bin/env bash
# Shared helpers for hook scripts. Source this file. Reads stdin JSON once.

# JQ_MISSING_REASON : what a guard tells the user when jq is missing (welcome.sh says it too). It goes
# into JSON through printf '%s', so each \n stays a JSON line-break escape.
JQ_MISSING_REASON='The Sendbird Client Plugin couldn'"'"'t check this call because jq isn'"'"'t installed.\nThe checks cover credentials, source citations, and destructive commands.\nApprove it only if you trust it. To turn the checks back on, install jq.'

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
  # One jq call checks the payload and reads the fields most hooks ask for (each jq call is a process, and
  # a tool call runs about seven hooks at once: in a 2026-11 audit on a loaded machine each took 1.2 to 1.8
  # seconds). jget answers these from HOOK_FIELDS; any other path, or a field that is not a string, is read
  # with jq as before.
  local f
  if f="$(printf '%s' "$HOOK_JSON" | jq -r "$HOOK_FIELDS_JQ" 2>/dev/null)" && [ -n "$f" ]; then
    eval "$f"
  else
    HOOK_JSON='{}'; HOOK_FIELDS_READ=1
  fi
}
# The fields jget answers without jq, as <path>=<variable suffix>. For each, read_stdin_json sets
# HF_<suffix> to s<value> when the field is a string, to e when it is absent, null, or false (jget prints
# nothing, as `// empty` does), and leaves it unset otherwise, so jget asks jq.
HOOK_FIELDS='.session_id=session_id .tool_name=tool_name .cwd=cwd .transcript_path=transcript_path .hook_event_name=hook_event_name .turn_id=turn_id .agent_id=agent_id .agent_type=agent_type .prompt=prompt .last_assistant_message=last_assistant_message .tool_input.command=ti_command .tool_input.file_path=ti_file_path .tool_input.path=ti_path .tool_input.pattern=ti_pattern .tool_input.skill=ti_skill .tool_input.subagent_type=ti_subagent_type .tool_input.content=ti_content .tool_input.new_string=ti_new_string'
HOOK_FIELDS_JQ='def f($n; v): v as $v | if ($v | type) == "string" then "HF_\($n)=s\($v | @sh)" elif $v == null or $v == false then "HF_\($n)=e" else empty end;
  "HOOK_FIELDS_READ=1",
  f("session_id"; .session_id), f("tool_name"; .tool_name), f("cwd"; .cwd), f("transcript_path"; .transcript_path),
  f("hook_event_name"; .hook_event_name), f("turn_id"; .turn_id), f("agent_id"; .agent_id), f("agent_type"; .agent_type),
  f("prompt"; .prompt), f("last_assistant_message"; .last_assistant_message),
  f("ti_command"; .tool_input.command?), f("ti_file_path"; .tool_input.file_path?), f("ti_path"; .tool_input.path?),
  f("ti_pattern"; .tool_input.pattern?), f("ti_skill"; .tool_input.skill?), f("ti_subagent_type"; .tool_input.subagent_type?),
  f("ti_content"; .tool_input.content?), f("ti_new_string"; .tool_input.new_string?)'

# command_text : the shell command of a Bash call, as one string. Codex may send it as an argument list
# (["/bin/zsh", "-lc", "cat > f <<'EOF' ..."]), which is joined with spaces; a string needs no jq call.
command_text() {
  if [ -n "${HOOK_FIELDS_READ:-}" ] && [ -n "${HF_ti_command+x}" ]; then jget .tool_input.command; return 0; fi
  printf '%s' "$HOOK_JSON" | jq -r '.tool_input.command | if type == "array" then join(" ") else (. // "") end' 2>/dev/null
}

# may_hold_credential <text> : 1 when core/commands/check-credential.sh cannot find anything in the text, so a
# hook can skip it (it starts six processes). Each of its patterns needs one of these words: PRIVATE KEY,
# eyJ (a JWT), password or passwd, secret, or token (api, access, session, auth). Matched in any case, which
# is wider than the check, never narrower.
may_hold_credential() {
  local rc=1 had=0
  shopt -q nocasematch && had=1
  shopt -s nocasematch
  case "$1" in
    *"private key"*|*eyj*|*passw*|*secret*|*token*) rc=0 ;;
  esac
  [ "$had" = 1 ] || shopt -u nocasematch
  return "$rc"
}

# is_noninteractive : 0 when SENDBIRD_NONINTERACTIVE turns on a non-interactive run (1, true, or
# yes in any case). Empty, 0, false, no, and any other value keep the run interactive. welcome.sh
# and run-summary-gate.sh both use this, so the model is told about the run summary exactly when
# the gate checks it. (Bracket patterns, not ${v,,}: stock macOS bash 3.2; and no tr, which is one more process.)
is_noninteractive() {
  case "${SENDBIRD_NONINTERACTIVE:-}" in
    1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# jget <jq-path> : echo a string field from $HOOK_JSON ('' if absent)
jget() {
  if [ -n "${HOOK_FIELDS_READ:-}" ]; then
    local pair n v
    for pair in $HOOK_FIELDS; do
      [ "${pair%%=*}" = "$1" ] || continue
      n="HF_${pair#*=}"
      if [ -n "${!n+x}" ]; then
        v="${!n}"
        [ "$v" = e ] || printf '%s' "${v#s}"
        return 0
      fi
      break
    done
  fi
  printf '%s' "$HOOK_JSON" | jq -r "$1 // empty" 2>/dev/null
}

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
# "Message Type: FINAL_ANSWER" from that agent ("Sender: /root/<name>") after it, while an agent of this
# session that hooks/session-state.sh saw start has not stopped.
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
    | "\($claude | length) \($codex | length)"' "$tp" 2>/dev/null)"
  set -- $n
  [ "${1:-0}" -gt 0 ] 2>/dev/null && return 0
  # Codex 0.164 sends a subagent's result as "Message Type: MESSAGE", not FINAL_ANSWER, so a spawn without a
  # FINAL_ANSWER counts as running only while hooks/session-state.sh still has an agent of this session that
  # started and has not stopped (SubagentStart / SubagentStop). Before this, every Codex run with a subagent
  # looked like an interim answer and skipped the run summary checks (a 2026-10 TC run).
  [ "${2:-0}" -gt 0 ] 2>/dev/null && agents_running
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
  local cwd="$1" source tmp_source local_path cited_by root="${CLAUDE_PLUGIN_ROOT:-.}" real_root
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
        # A public page that a curated entry cites stands for that entry (docs/AGENT_CONTRACT.md "Cite the
        # curated entry"), so the customer's code and the answer carry a page they can open instead of a
        # plugin path. The entries that cite it are searched instead of the page: this works offline, adds
        # no wait, and accepts nothing that citing those entries' paths would not.
        cited_by="$(curated_files_citing "$root" "$source")"
        if [ -n "$cited_by" ]; then
          while IFS= read -r local_path; do RESOLVED_SOURCES+=("$local_path"); done <<< "$cited_by"
          continue
        fi
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

# curated_files_citing <plugin root> <url> : the curated files that cite the page, one per line. The URL must
# end where the citation ends (a longer URL that starts with it does not count; a period that ends the
# sentence does not change it).
curated_files_citing() {
  local esc
  esc="$(printf '%s' "$2" | sed 's/[][\.*^$+?(){}|]/\\&/g')"
  grep -rlE -- "${esc}([^A-Za-z0-9_/#?=&%.-]|\.([^A-Za-z0-9]|\$)|\$)" "$1/knowledge/curated" 2>/dev/null || true
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

# answer_on_screen : 0 when the customer reads the conversation as it goes, in the terminal or the VS Code
# extension (CLAUDE_CODE_ENTRYPOINT cli or claude-vscode, as hooks/first-run-notice.sh reads it), and the run
# is not a non-interactive one. `claude -p` (sdk-cli) and Agent SDK programs return only the last reply, and
# a missing value says nothing, so both count as not on screen.
answer_on_screen() {
  is_noninteractive && return 1
  case "${CLAUDE_CODE_ENTRYPOINT:-}" in cli|claude-vscode) return 0 ;; *) return 1 ;; esac
}

# gate_emit : prints the Stop decision JSON on stdin, made to ask for an addition when the answer is on
# screen. A send-back asks for the whole answer again because a non-interactive caller sees only the last
# reply; in the terminal that showed the customer the same answer twice with a red "Stop hook error" line
# between them, in 11 of 13 work turns of a 2026-11 audit. There the reply that follows carries only what
# the answer left out.
# customer_lines : prints the deny or block JSON on stdin with the first line of its reason (the line written
# for the customer: hooks show the reason in full) in Korean when the latest request is in Korean. The
# lines after it are for the agent and stay in English. A 2026-11 audit found every first line in English,
# also for customers who wrote in Korean. A line without a Korean version stays as it is.
customer_lines() {
  jq --arg req "$(turn_user_prompt)" '
    def ko_first: (split("\n")) as $l | ($l[0] | split(": ")) as $h
      | if ($h | length) < 2 then . else
        ([$h[0], ($h[1:] | join(": "))]) as [$who, $what]
        | ([["This request didn'"'"'t ask for a build or a test run, so this command didn'"'"'t run. To run it, ask for it, for example \"build it\" or \"run the tests\".",
             "이번 요청에는 빌드나 테스트 실행이 없어서 이 명령을 실행하지 않았습니다. 실행하시려면 「빌드해 줘」나 「테스트 돌려 줘」처럼 말씀해 주세요."],
            ["This change uses Sendbird APIs that weren'"'"'t checked against the Sendbird docs or your installed SDK, so it wasn'"'"'t made. They are checked first and the change is made again; you don'"'"'t need to do anything.",
             "Sendbird 문서나 설치된 SDK로 확인하지 않은 Sendbird API가 들어 있어서 이 변경을 적용하지 않았습니다. API를 먼저 확인하고 다시 적용하므로 따로 하실 일은 없습니다."],
            ["The token you pasted isn'"'"'t copied into the next step, so this step didn'"'"'t start.",
             "붙여 넣으신 토큰은 다음 단계로 넘기지 않으므로 이 단계를 시작하지 않았습니다."],
            ["The upgrade is paused until the upgrade rules for your target versions are read.",
             "목표 버전의 업그레이드 규칙을 읽을 때까지 업그레이드를 멈췄습니다."],
            ["The answer included the token you pasted.", "답에 붙여 넣으신 토큰이 그대로 들어 있었습니다."],
            ["The answer left out sources or check results from the work done for your request.", "답에서 이번 작업의 출처나 검사 결과가 빠졌습니다."],
            ["The upgrade answer left out version details or where they came from.", "업그레이드 답에서 버전 정보나 그 출처가 빠졌습니다."],
            ["The answer asked for your App ID, but this task doesn'"'"'t need it.", "이 작업에는 App ID가 필요 없는데 답에서 App ID를 물었습니다."],
            ["The answer linked to web pages instead of the Sendbird docs it used.", "답에 참고한 Sendbird 문서 대신 웹 페이지 링크만 달렸습니다."],
            ["The answer mentioned Sendbird APIs without saying where the information came from.", "답에 나온 Sendbird API의 출처가 빠졌습니다."],
            ["A new answer follows.", "고쳐 쓴 답이 이어집니다."],
            ["What it left out follows.", "빠진 내용이 이어집니다."]]
           | reduce .[] as $p ($what; split($p[0]) | join($p[1]))) as $ko
        | ([$who + ": " + $ko] + $l[1:]) | join("\n") end;
    if ($req | test("[가-힣]")) then
      (if .reason then .reason |= ko_first else . end)
      | (if .hookSpecificOutput.permissionDecisionReason then .hookSpecificOutput.permissionDecisionReason |= ko_first else . end)
    else . end'
}

gate_emit() {
  if answer_on_screen; then
    jq '.reason |= (sub("A new answer follows\\."; "What it left out follows.")
      | sub("Write the whole answer again as the reply itself \\(the user may see only this reply, so do not say it is repeated or mention this check\\)";
            "The customer has already read this answer on screen, so do not write it again or say that it was incomplete: reply with only what it left out, as a short addition that follows on from it (do not mention this check)"))' | customer_lines
  else
    customer_lines
  fi
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
# (build = make) is not a build request. A request to run the tests ("run the unit tests", "테스트 돌려 줘",
# "fix the failing CI") counts too: ./gradlew test, swift test, xcodebuild test, and npm test build or run the project, and in
# a 2026-11 audit "테스트 돌려 줘" on an iOS app was denied its xcodegen and the tests never ran.
prompt_asks_build() {
  printf '%s' "$1" | grep -Eiq '\b(type-?check(s|ed|ing)?|tsc|xcodebuild|gradlew|assemble(debug|release)|compil(e|es|ed|ing|er))\b|\b(run|do|try|start|kick off)[[:space:]]+(a[[:space:]]+|the[[:space:]]+|an?[[:space:]]+)?(build|typecheck)\b|\bbuild[[:space:]]+(it|and[[:space:]]+(run|launch|test)|(the|my|this|your|our)[[:space:]]+(app|project|code|ios app|android app|web app))\b|\b(build|bundler|gradle|xcode|metro|webpack|vite)[[:space:]]+(error|errors|fails?|failed|failure|failing|log|output)\b|빌드|컴파일|타입[[:space:]]*체크|타입[[:space:]]*검사' && return 0
  printf '%s' "$1" | grep -Eiq '\b(run|rerun|re-run|execute|kick off|start)[[:space:]]+((the|my|our|all|unit|ui|integration|e2e|instrumented|failing|existing|test)[[:space:]]+)*(tests?|test suites?|specs?)\b|\b(npm|yarn|pnpm|bun|swift|xcodebuild|gradlew)[[:space:]]+test\b|\bfailing[[:space:]]+(ci|tests?|checks?)\b|\b(ci|tests?)[[:space:]]+((is|are)[[:space:]]+)?(failing|fails|failed|broken|red)\b|테스트[[:space:]]*(를|을|가|도|만)?[[:space:]]*(돌려|돌리|실행|통과|깨|실패)'
}

# uses_sendbird <dir> : 0 when the project in <dir> uses a Sendbird SDK. The guards that read code or answers
# for Sendbird API (source-claim-guard.sh, final-answer-gate.sh) ask this before they take a common name such
# as BaseMessage or "error code 235050" for Sendbird's: in a 2026-11 audit a LangChain.js project with no
# Sendbird in it was denied a file that used BaseMessage, and a Postgres error code answer was sent back.
# It counts: the plugin's project profile (<stateDir>/profile.json, written by tools/detection/detect.sh) in
# <dir> or a folder above it, or a package manifest, lockfile, or Xcode or Gradle project file that names
# Sendbird in <dir>, in one of the four folders above it, or up to four folders below it (dependency and build
# folders are skipped). The look below is skipped for the home folder and /, which can take seconds, and its
# answer is kept per session and folder (sendbird-scan-<session_id>): a yes for the session, a no for ten
# minutes, so an app that setup creates in a folder below is found again soon after.
uses_sendbird() {
  local dir="$1" d i f sd scan cached found
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  sd="$(jq -r '.stateDir // empty' "${CLAUDE_PLUGIN_ROOT:-$(dirname "${BASH_SOURCE[0]}")/../..}/config/plugin-config.json" 2>/dev/null)"
  d="$dir"
  for i in 0 1 2 3 4; do
    [ -n "$sd" ] && [ -f "$d/$sd/profile.json" ] && return 0
    for f in package.json Package.swift Package.resolved project.yml Podfile Podfile.lock build.gradle build.gradle.kts settings.gradle settings.gradle.kts pubspec.yaml; do
      [ -f "$d/$f" ] && grep -qi sendbird "$d/$f" 2>/dev/null && return 0
    done
    [ -e "$d/.git" ] && break
    [ "$d" = / ] && break
    d="$(dirname "$d")"
  done
  case "$dir" in /|"${HOME:-/}"|"${HOME:-/}/") return 1 ;; esac
  scan="$(session_state_file sendbird-scan)"
  if [ -n "$scan" ] && [ -f "$scan" ]; then
    cached="$(awk -F'\t' -v d="$dir" -v now="$(date +%s)" '$3 == d && ($1 == "yes" || now - $2 < 600) { r = $1 } END { print r }' "$scan")"
    case "$cached" in yes) return 0 ;; no) return 1 ;; esac
  fi
  found="$(find "$dir" -maxdepth 4 \( -name node_modules -o -name Pods -o -name .git -o -name build -o -name .build \
      -o -name DerivedData -o -name .gradle -o -name dist -o -name .next \) -prune -o -type f \( -name package.json \
      -o -name Package.swift -o -name Package.resolved -o -name project.yml -o -name project.pbxproj -o -name Podfile \
      -o -name Podfile.lock -o -name 'build.gradle*' -o -name 'settings.gradle*' -o -name libs.versions.toml \
      -o -name pubspec.yaml \) -exec grep -li sendbird {} + 2>/dev/null | head -1)"
  if [ -n "$scan" ]; then
    mkdir -p "$(dirname "$scan")" 2>/dev/null && (umask 077; printf '%s\t%s\t%s\n' "$([ -n "$found" ] && echo yes || echo no)" "$(date +%s)" "$dir" >> "$scan")
  fi
  [ -n "$found" ]
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
#   syllable comes right before it;
# - a git commit or other hash named as one: a run of hex digits right after commit, sha, revision, hash,
#   커밋, or 해시 ("Session token refresh broke after commit 9914c0ce..." in a 2026-11 audit, whose answer
#   was sent back for repeating the commit). A hex run without such a word still counts.
# request_tokens <text> : the tokens in that text, one per line
request_tokens() {
  jq -rn --arg req "$1" '
    [ ($req | match("(?i)(token|secret|session|api[ _-]?key|password|bearer|credential|토큰|시크릿|비밀|세션|(?<![가-힣])키)([^\\n]{0,60}?)(?<![A-Za-z0-9_/\\\\-])([A-Za-z0-9_-]{24,})(?![A-Za-z0-9_/\\\\-]|\\.[A-Za-z0-9])"; "g")
        | select((.captures[2].string | test("^[0-9A-Fa-f]+$")) and (.captures[1].string | test("(?i)(commit|sha(1|256)?|revision|rev|hash|커밋|해시)[[:space:]:#=@]*(은|는|이|가|을|를)?[[:space:]]*$")) | not)
        | .captures[2].string),
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
# on stdin, one per line, without the folder and the line (types.d.ts for node_modules/.../types.d.ts:52).
# The name is the cell's first file name (with an extension) or URL, not its first word: in a 2026-11 audit
# run a cell read "grep for "GroupChannel" found only ... (`.sendbird-client/cache/uikit/api-surface.md:18`)",
# and an answer that kept api-surface.md was sent back for leaving out "grep". A cell with neither prints nothing.
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
      cell = $col; gsub(/[`()\[\]]/, " ", cell); v = ""
      nt = split(cell, t, /[[:space:]]+/)
      for (k = 1; k <= nt; k++) {
        w = t[k]; sub(/[,;]+$/, "", w); sub(/\.$/, "", w)
        if (w ~ /^https?:\/\// || w ~ /\.[A-Za-z][A-Za-z0-9]*(:[0-9][0-9,-]*)?$/) { v = w; break }
      }
      if (v == "") next
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
#   other-skill sendbird-cli:<name>    a Sendbird CLI plugin skill the turn started (its sendbird-setup
#                                      choosing an app): the citation checks skip a turn that ran only these
# skill_trace_line <name> : the trace line for a skill the turn started, from the Skill tool or a request
# that starts with /<name> or $<name>. A Sendbird CLI plugin skill (sendbird-cli:<name>) is other-skill;
# every other skill keeps its bare name, as before.
skill_trace_line() {
  local s="${1#[/\$]}"
  [ -n "$s" ] || return 0
  case "$s" in
    sendbird-cli:*) printf 'other-skill %s' "$s" ;;
    *) printf 'skill %s' "${s##*:}" ;;
  esac
}
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

# answer_json_block <text> : the last ```json fenced block of an answer (the run summary), or nothing
answer_json_block() {
  printf '%s\n' "$1" | awk '/^[[:space:]]*```json[[:space:]]*$/ {on=1; buf=""; next}
    on && /^[[:space:]]*```[[:space:]]*$/ {on=0; last=buf; next} on {buf = buf $0 "\n"} END {printf "%s", last}'
}
# answer_asks_app_id <text> : 0 when the answer stops to ask for the App ID: a needs_input run summary with a
# question about it, or (without a run summary) a prose line about the App ID that asks for it
answer_asks_app_id() {
  local block
  block="$(answer_json_block "$1")"
  if [ -n "$block" ]; then
    printf '%s' "$block" | jq -e '.status == "needs_input"
      and any((.questions // [])[]; tostring | test("app[ _-]?id|앱 ?id"; "i"))' >/dev/null 2>&1
    return
  fi
  printf '%s\n' "$1" | grep -Ei '(app[ _-]?id|앱 ?id)' | grep -Eiq '\?|알려 ?(주|줘)|입력해 ?(주|줘)'
}

# CHAT_INIT_RE : a Chat SDK init call (iOS initialize, Android and JS init)
CHAT_INIT_RE='SendbirdChat\.(initialize|init)\('
# template_init_files <plugin root> <platform> <host> : the template files of that host that call SendbirdChat
# init, one per line: the chat/ folder first, then every other product folder. The Chat template is not the
# only verified init: a product that runs on top of Chat, such as Desk, has a template that initializes Chat
# itself. In a 2026-10 TC run the iOS agent spliced the SwiftUI Desk template, was sent back for init code
# without the Chat template, added ChatSession next to it, and moved Desk authentication out of
# onLoginSucceeded.
template_init_files() {
  local base="$1/templates/$2/$3" d f
  [ -d "$base" ] || return 0
  for d in "$base/chat" "$base"/*; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      case "$f" in */_README.md) continue ;; esac
      grep -qE "$CHAT_INIT_RE" "$f" 2>/dev/null && printf '%s\n' "$f"
    done
  done | awk '!seen[$0]++'
}
# template_markers <plugin root> <platform> <host> : the names a Chat init template of that host declares
# (a type, an object, or an exported function of the template_init_files), at least six characters long,
# one per line. A run that splices one of those templates keeps them; one that writes its own init code
# has none of them.
template_markers() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -oE '^((public|internal|private|final|open|data|export|default|async)[[:space:]]+)*(class|struct|enum|actor|object|fun|func|function|interface)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$f" \
      | awk '{print $NF}'
  done < <(template_init_files "$@") | awk 'length($0) >= 6 && !seen[$0]++'
}

# cited_sources <text> : what each "source:" or "출처:" marker in an answer cites, one per line, for
# resolve_cited_sources. A Markdown link (source: [knowledge/curated/ios/cross-cutting/errors.md — Diagnosing
# connection failures](/abs/path/errors.md)) gives the first word of its text and its target; a plain marker
# gives the word after it (a path, path:line, or URL), cut after the file name when Korean or a closing
# backtick follows it ("`errors.md`의"). 근거: (basis) counts as a marker too. In a 2026-10 Codex TC run the
# link was read as "[knowledge/..." and never resolved, and a later answer that wrote 근거: was not read at
# all, so cited answers were sent back as citing nothing.
cited_sources() {
  local m
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    printf '%s\n' "$m" | sed -E 's/^[^[]*\[([^]]*)\].*$/\1/' | awk '{print $1}'
    printf '%s\n' "$m" | sed -E 's/^.*\]\(([^)]*)\)$/\1/'
  done < <(printf '%s\n' "$1" | grep -Eio '(source:|출처:|근거:)[[:space:]]*\[[^]]*\]\([^)[:space:]]+\)')
  printf '%s\n' "$1" | grep -Eio '(source:|출처:|근거:)[[:space:]]*[^[)[:space:]][^)[:space:]]*' \
    | sed -E 's/^([Ss][Oo][Uu][Rr][Cc][Ee]:|출처:|근거:)[[:space:]]*//' \
    | sed -E 's/(\.(md|swift|kt|java|ts|tsx|js|jsx|json|swiftinterface))[^:0-9A-Za-z_.,-].*$/\1/'
}

# curated_page_links <root> <text> : each https:// link in the text, with or without a source marker, that is
# a public page a curated entry under <root> cites (curated_files_citing). The contract asks an answer to cite
# that page, with no marker: in a 2026-11 audit run an answer that cited the error code page in parentheses
# ("오류 코드 페이지(https://sendbird.com/docs/...)에서") was sent back as citing nothing. Only pages an entry
# cites count, so reading them fetches nothing.
curated_page_links() {
  local link
  while IFS= read -r link; do
    public_source_url "$link" && [ -n "$(curated_files_citing "$1" "$link")" ] && printf '%s\n' "$link"
  done < <(printf '%s\n' "$2" | LC_ALL=C grep -Eo 'https://[A-Za-z0-9._~:/?#@!$&*+,;=%-]+' | LC_ALL=C sed -E 's/[.,;:!?]+$//' | awk '!seen[$0]++')
  return 0
}
