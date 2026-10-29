#!/usr/bin/env bash
# Stop hook for non-interactive runs (SENDBIRD_NONINTERACTIVE=1, true, or yes): the caller, a CLI or a
# script, decides what to do next from the run summary the answer ends with, so its shape is
# checked before the run ends. A follow-up request sent with --resume does not get the
# session-start instructions again, and such a run once ended with "status": "ok" and no
# schemaVersion/skill. On a problem, block and say what is wrong. A stop that follows a block
# (stop_hook_active) is checked again, but blocks only for a kind of problem this stop chain has not
# sent back yet, and at most twice in all: a rewrite once moved an env loader step into manualSteps
# after a block for a missing summary, and the plain stop_hook_active guard let it through. The kinds
# sent back are kept per session_id (Claude and Codex both send it) in the plugin data folder or the
# temp folder; with no session_id or no record, a stop after a block passes as before, so this cannot
# loop. Interactive
# sessions are not checked. Fail open when the schema or the answer cannot be read.
# A completed run that changed app files must also list its checks (docs/AGENT_CONTRACT.md sections 4
# and 6); the block asks for the whole answer again, since a run once re-sent only the json block.
# On a JS project, a manualSteps or nextSteps entry or a question that asks for a bundler or env loader to
# read the App ID is sent back too (docs/AGENT_CONTRACT.md section 3).
# A stop while a subagent started in this turn is still running is not checked: the main session ends
# its turn with an interim answer and waits for the agent's result, and the final answer comes in a
# later turn. In a 2026-10 TC round, 17 Claude runs were sent back for that interim answer and put a
# needs_input or failed summary with no changes in it, which a caller reading the first result took
# as the outcome (hooks/lib/hook-helpers.sh agent_pending: the Stop input's background_tasks, else the
# transcript, else the agents hooks/session-state.sh saw start and not stop, since `claude -p
# --no-session-persistence` writes no transcript).
# A run that adds Chat SDK init code without the detected host's init template is sent back too.
# A manualSteps entry that asks the customer to call a helper this run added, or the sign-in function it
# wired, from the app's sign-in or sign-out is sent back as well (docs/AGENT_CONTRACT.md section 3).
# A needs_input summary that asks the apply-fix question when the request itself asked for the fix
# ("fix it", "apply", "고쳐 줘", "적용해 줘"; docs/AGENT_CONTRACT.md section 7) is sent back once too.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

is_noninteractive || exit 0
# an interim answer while a subagent of this turn still runs: the final answer is checked later
agent_pending && exit 0
active="$(jget '.stop_hook_active')"
sid="$(jget '.session_id' | tr -c 'A-Za-z0-9_-' _)"
[ "$active" = "true" ] && [ -z "$sid" ] && exit 0
# the record of the kinds of problem this stop chain sent back (see sent_kind below)
mark=""
[ -n "$sid" ] && mark="${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${TMPDIR:-/tmp}}}/run-summary-gate-$sid"
[ "$active" = "true" ] && { [ -r "$mark" ] || exit 0; }
SCHEMA="${CLAUDE_PLUGIN_ROOT:-$HERE/..}/core/schemas/run-summary.schema.json"
[ -r "$SCHEMA" ] || exit 0
# the plugin's own folder in the project (profile, SDK cache); a run that wrote only there changed no app file
state_dir="$(jq -r '.stateDir // empty' "${CLAUDE_PLUGIN_ROOT:-$HERE/..}/config/plugin-config.json" 2>/dev/null || true)"

text="$(final_answer_text)"
[ -n "$text" ] || exit 0

# A manualSteps entry about building or type-checking the project, including a note that this run
# did not build it (docs/AGENT_CONTRACT.md section 3: a build is not a hand-off step). Running the
# app on a device, simulator, emulator, or browser, and work on a server or signing, stay allowed.
# The same rule as tests/e2e/lib/run-summary.py "hands the build or type check off to the customer".
build_step='^(?!.*\b(device|simulator|emulator|browser|token|server|backend|endpoint|dashboard|signing|certificate)\b).*(\b(xcodebuild|gradlew|assemble(debug|release)|tsc)\b|\b(npm|yarn|pnpm) (run )?(build|typecheck|type-check)\b|\b(build|compile|type-?check)\w*\s+(the\s+|your\s+)?(project|app|module|scheme|target|code)\b)'

# A manualSteps or nextSteps entry on a JS project that asks for a bundler, an env loader, or another
# config mechanism to read the App ID, or to switch its read to import.meta.env or process.env. With no
# env loader, the config module already reads the App ID from configuration, and the plugin never asks
# for a bundler or env loader (docs/AGENT_CONTRACT.md section 3, knowledge/curated/js/setup.md "App ID").
# Only steps that name the App ID match: a token server URL or a placeholder to replace stays allowed.
# The same rule as tests/e2e/lib/run-summary.py "asks for a bundler or env loader to read the App ID".
appid_loader_step='^(?=.*(\b|_)app[ _-]?id\b).*(\b((install|add|set ?up|configure|ensure|use|need|choose|pick|adopt|introduce|wire|point|move|ask)\w*|load(s|ed|ing)?)\b.{0,120}\b(vite|webpack|parcel|bundler|dotenv|react-native-config|env(ironment)?[ -]?(loader|mechanism|variable|file|config(uration)?)|env-(based|driven)|config(uration)? (mechanism|loader|library)|loader)\b|\b(bundler|loader|config(uration)? mechanism)\b.{0,40}\b(add|install|set ?up|choose|pick|introduce|adopt)\w* (one|it|that)\b|\b(switch|change|point|move|have|make|update)\w*\b.{0,80}(import\.meta\.env|process\.env))'
# JS only: the project profile's platform when detection wrote one, else a package.json in the project
cwd="$(jget '.cwd')"; cwd="${cwd:-$PWD}"
platform=""
[ -n "$state_dir" ] && platform="$(jq -r '.platform // empty' "$cwd/$state_dir/profile.json" 2>/dev/null || true)"
case "$platform" in
  js) is_js=true ;;
  ios|android) is_js=false ;;
  *) if [ -f "$cwd/package.json" ]; then is_js=true; else is_js=false; fi ;;
esac

# The request asks for the fix itself (docs/AGENT_CONTRACT.md section 7: "fix it", "apply", "go ahead",
# "고쳐 줘", "적용해 줘", or --apply), unless it says not to. consent holds the words that asked for it.
consent_re='(\bfix (it|this|that|them|these|those)\b|\bgo ahead\b|\bapply\b|--apply\b|고쳐 ?(줘|줄래|주세요|주실래요|줘요|봐|놔)|수정해 ?(줘|줄래|주세요|줘요)|적용해 ?(줘|줄래|주세요|줘요|봐)|적용 ?부탁)'
no_consent_re="(\b(don'?t|do not|never|without) (fix|apply|chang)|고치지 ?(마|말|않)|적용하지 ?(마|말|않)|수정하지 ?(마|말|않))"
# a question that asks whether to apply the fix (the apply-fix question by its wording, when its id differs)
fix_question='(적용할까요|적용해도 될까요|고칠까요|수정할까요|바꿀까요|\bapply (this|the|that|it|these)\b|\b(shall|should|may) i (apply|fix|make)\b|\bwant me to (apply|fix)\b)'
request="$(turn_user_prompt)"
consent=""
if [ -n "$request" ] && ! printf '%s' "$request" | grep -Eiq "$no_consent_re"; then
  consent="$(printf '%s' "$request" | grep -Eio "$consent_re" | head -1)"
fi

# the last ```json fenced block of the answer
block="$(printf '%s\n' "$text" | awk '/^[[:space:]]*```json[[:space:]]*$/ {on=1; buf=""; next}
  on && /^[[:space:]]*```[[:space:]]*$/ {on=0; last=buf; next} on {buf = buf $0 "\n"} END {printf "%s", last}')"

if [ -z "$block" ]; then
  problems="the answer does not end with a fenced json run summary"
elif ! printf '%s' "$block" | jq -e 'type == "object"' >/dev/null 2>&1; then
  problems="the last json block is not a JSON object"
else
  problems="$(printf '%s' "$block" | jq -r --slurpfile s "$SCHEMA" --arg build "$build_step" --arg sd "$state_dir" \
    --arg loader "$appid_loader_step" --argjson js "$is_js" --arg consent "$consent" --arg fixq "$fix_question" '
    ($s[0]) as $S | . as $d
    | ($S.properties.status.enum) as $st
    | ($S.properties.checks.items.properties.result.enum) as $cr
    | [ ($S.required[] as $k | select(($d | has($k)) | not) | "missing field \($k)"),
        ($d | keys[] as $k | select(($S.properties | has($k)) | not) | "unknown field \($k)"),
        (if ($d.status | IN($st[]) | not) then "status \($d.status | tojson) is not one of \($st | join(", "))" else empty end),
        (if ($d | has("schemaVersion")) and $d.schemaVersion != $S.properties.schemaVersion.const then "schemaVersion must be \($S.properties.schemaVersion.const | tojson)" else empty end),
        (if ($d.changes | type) != "array" then (if ($d | has("changes")) then "changes must be an array" else empty end)
         else ($d.changes[] | if type != "object" then "each changes entry must be an object with path and action"
               else (if (.path | type) != "string" or (.path | test("^(/|\\.\\./)")) then "changes path must be relative to the project" else empty end),
                    (if (.action | IN("created","modified","deleted") | not) then "changes action must be created, modified, or deleted" else empty end),
                    (keys[] | select(IN("path","action","summary") | not) | "unknown changes field \(.)") end) end),
        (if ($d.manualSteps | type) != "array" and ($d | has("manualSteps")) then "manualSteps must be an array of strings" else empty end),
        (if ($d.manualSteps | type) == "array" then ($d.manualSteps[] | strings | select(test($build; "i"))
          | "manualSteps entry \(tojson) is about building or type-checking the project, which is not a hand-off (docs/AGENT_CONTRACT.md section 3): remove it, and at most say once in the answer text, outside the json block, that this run did not build the project") else empty end),
        (if $js then ("manualSteps", "nextSteps") as $f | ($d[$f] | if type == "array" then .[] else empty end) | strings | select(test($loader; "i"))
          | "\($f) entry \(tojson) asks for a bundler, env loader, or other config mechanism to read the App ID. On a JS project without an env loader, the config module (for example src/sendbird/config.ts) already reads the App ID from configuration, and the plugin never asks for a bundler or env loader (docs/AGENT_CONTRACT.md section 3, knowledge/curated/js/setup.md \"App ID\"): drop that step, do not move the suggestion to nextSteps, checks, or the answer text, and when the App ID is still a placeholder keep only a step such as \"Replace the placeholder App ID in src/sendbird/config.ts with your real Sendbird App ID\"" else empty end),
        # a question that offers an env loader for the App ID is the same suggestion; the question text,
        # labels, and options are read as one string, so a label such as "Add an env loader (.env.local)"
        # counts with the App ID its question names (the same join as tests/e2e/lib/run-summary.py)
        (if $js then ($d.questions | if type == "array" then .[] else empty end) | objects
          | select(([.question] + (.labels | if type == "array" then . else [] end) + (.options | if type == "array" then . else [] end)) | map(strings) | join(" | ") | test($loader; "i"))
          | "questions entry \(.id // "" | tojson) asks for a bundler, env loader, or other config mechanism to read the App ID. On a JS project without an env loader, the config module (for example src/sendbird/config.ts) already reads the App ID from configuration, so the request to read it from configuration is met and there is nothing to ask (docs/AGENT_CONTRACT.md section 3, knowledge/curated/js/setup.md \"App ID\"): drop that question, do not move the suggestion to manualSteps, nextSteps, checks, or the answer text, and if it was the only reason for needs_input, finish as completed, listing the config module as a passed check and, when the App ID is still a placeholder, only a step such as \"Replace the placeholder App ID in src/sendbird/config.ts with your real Sendbird App ID\"" else empty end),
        (if $d.status == "needs_input" and (($d.questions // []) | length) == 0 then "needs_input needs at least one questions entry" else empty end),
        (if ($d.questions | type) == "array" then ($d.questions[] | select(type != "object" or (.id | type) != "string" or (.question | type) != "string")
          | "each questions entry must be an object with id and question (for a yes/no question about applying a fix: id \"apply-fix\", options [\"yes\", \"no\"])")
         elif ($d | has("questions")) then "questions must be an array" else empty end),
        # docs/AGENT_CONTRACT.md section 7: the request already gave the yes the apply-fix question asks for
        (if $consent != "" and $d.status == "needs_input"
            and any(($d.questions // [])[]; (if type == "object" then ((.id // "") == "apply-fix" or ((.question // "") | tostring | test($fixq; "i"))) else (tostring | test($fixq; "i")) end))
         then "the request already asks to apply the fix (it says \($consent | tojson)), so the apply-fix question is answered: apply the fix now the way the skill says (through the platform agent), then end with status completed, the changed files under changes, and the checks (docs/AGENT_CONTRACT.md section 7). Ask only about a value the fix still needs" else empty end),
        (if $d.status == "needs_input" and (($d.changes // []) | length) > 0 then "needs_input must not list changes" else empty end),
        (if ($d.status | IN("failed","declined")) and ((($d.reason // "") | type) != "string" or ($d.reason // "") == "") then "\($d.status) needs a reason" else empty end),
        (if ($d | has("checks")) and ($d.checks | type) != "array" then "checks must be an array"
         elif ($d | has("checks")) then ($d.checks[] | if type != "object" or (.name | type) != "string" or .name == "" then "each checks entry needs a name"
               elif (.result | IN($cr[]) | not) then "checks result \(.result | tojson) is not one of \($cr | join(", "))"
               else (keys[] | select(IN("name","result","detail") | not) | "unknown checks field \(.)") end)
         else empty end),
        (if ($d | has("nextSteps")) and (($d.nextSteps | type) != "array" or any($d.nextSteps[]; type != "string")) then "nextSteps must be an array of strings" else empty end),
        # docs/AGENT_CONTRACT.md sections 4 and 6: a run that changed app files reports each check
        (if $d.status == "completed" and (($d.checks // []) | length) == 0
            and any(($d.changes // [])[]; (.path | type) == "string" and ($sd == "" or (.path | startswith($sd + "/") | not)))
         then "the run changed app files but lists no checks: put each check from docs/AGENT_CONTRACT.md section 4 and the skill'"'"'s own checks under checks, as pass, fail, or not_run" else empty end)
      ] | unique | .[]' 2>/dev/null)" || exit 0
fi
# docs/AGENT_CONTRACT.md section 3 "Finish what the project allows": calling the disconnect helper a run
# added (or the sign-in function it wired) is not a manualSteps entry. In five 2026-10 TC rounds a run
# added LoginService.onLogoutRequested() and still listed "Call ... onLogoutRequested() from sign-out"
# under manualSteps. An entry that asks to call, wire, or invoke something from the app's sign-in or
# sign-out and names a function (name( or `name`) that a file under changes contains is sent back.
helper_verb='(^|[^A-Za-z])(call|calls|calling|wire|wiring|hook|invoke|invoking|trigger|run)([^A-Za-z]|$)'
auth_word='sign[- ]?(in|out)|log[- ]?(in|out)|logout|login|signout|signin|로그인|로그아웃'
if [ -n "$block" ] && printf '%s' "$block" | jq -e 'type == "object"' >/dev/null 2>&1; then
  changed="$(printf '%s' "$block" | jq -r '(.changes // []) | if type == "array" then .[] else empty end | objects
    | select(.action != "deleted") | .path | strings | select(test("^(/|\\.\\./)") | not)' 2>/dev/null)"
  while IFS= read -r step; do
    [ -n "$step" ] && [ -n "$changed" ] || continue
    printf '%s' "$step" | grep -Eiq "$helper_verb" || continue
    printf '%s' "$step" | grep -Eiq "$auth_word" || continue
    found=""
    while IFS= read -r id; do
      [ "${#id}" -ge 4 ] || continue
      while IFS= read -r rel; do
        [ -n "$rel" ] && [ -f "$cwd/$rel" ] || continue
        if grep -Eq "(^|[^A-Za-z0-9_])${id}([^A-Za-z0-9_]|$)" "$cwd/$rel" 2>/dev/null; then found="$id $rel"; break; fi
      done <<< "$changed"
      [ -z "$found" ] || break
    done < <(printf '%s' "$step" | { grep -Eo '[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*\(|`[A-Za-z_][A-Za-z0-9_.]*`' || true; } \
      | sed -E 's/[`(]//g; s/.*\.//' | awk '!seen[$0]++')
    [ -n "$found" ] || continue
    problems="${problems}${problems:+$'\n'}manualSteps entry $(printf '%s' "$step" | jq -Rs .) asks the customer to call ${found%% *}, which ${found#* } (a file this run changed) contains. Calling a helper this run added, or the sign-in function it wired, is not a hand-off (docs/AGENT_CONTRACT.md section 3, \"Finish what the project allows\"): drop the entry. When the app has a sign-out or logout function, the helper is called from it in the project; when it has none, name the helper, its file, and that it disconnects and removes the handlers this run added in the answer text instead, and keep manualSteps for work outside the project"
  done < <(printf '%s' "$block" | jq -r '(.manualSteps // []) | if type == "array" then .[] else empty end | strings' 2>/dev/null)
fi
# The platform agents splice the verified Chat init template of the detected host
# (templates/<platform>/<host>/chat/, agents/*-agent.md) instead of writing their own init and connect code.
# In a 2026-10 Codex TC run the iOS agent rewrote it as its own class and left out the template's
# bootstrap and unread-count observer types. A run whose changed files add a Chat SDK init call
# (CHAT_INIT_RE; lines git shows as added, or a file the run created) while no changed file uses a name the
# template declares (template_markers) is sent back once. A source comment that only names the template
# folder does not count: a later Codex run added "// source: templates/ios/uikit/chat/InitConnect.swift" to
# its own rewritten class and passed an earlier version of this check. Every verified template of the host
# that initializes Chat counts (template_init_files), so a run that splices the Desk template on its own is
# not sent back for leaving out the Chat one.
if [ -n "$block" ] && [ -n "$state_dir" ] && printf '%s' "$block" | jq -e 'type == "object"' >/dev/null 2>&1; then
  prof="$cwd/$state_dir/profile.json"
  t_plat="$(jq -r '.platform // empty' "$prof" 2>/dev/null)"; t_host="$(jq -r '.host // empty' "$prof" 2>/dev/null)"
  markers=""
  [ -n "$t_plat" ] && [ -n "$t_host" ] && markers="$(template_markers "${CLAUDE_PLUGIN_ROOT:-$HERE/..}" "$t_plat" "$t_host")"
  if [ -n "$markers" ]; then
    root="${CLAUDE_PLUGIN_ROOT:-$HERE/..}"
    t_dir="$(template_init_files "$root" "$t_plat" "$t_host" | sed "s#^$root/##; s#/[^/]*\$##" | awk '!seen[$0]++' | paste -sd ',' - | sed 's/,/, /g')"
    in_git=0; git -C "$cwd" rev-parse --verify -q HEAD >/dev/null 2>&1 && in_git=1
    init_file=""; named=0
    while IFS=$'\t' read -r rel action; do
      [ -n "$rel" ] && [ -f "$cwd/$rel" ] || continue
      case "$rel" in *.swift|*.kt|*.java|*.ts|*.tsx|*.js|*.jsx) ;; *) continue ;; esac
      grep -Fwq -f <(printf '%s\n' "$markers") "$cwd/$rel" 2>/dev/null && named=1
      [ -z "$init_file" ] || continue
      if [ "$in_git" -eq 1 ] && git -C "$cwd" cat-file -e "HEAD:$rel" 2>/dev/null; then
        added="$(git -C "$cwd" diff HEAD -- "$rel" 2>/dev/null | grep '^+' | grep -v '^+++')"
      elif [ "$in_git" -eq 1 ] || [ "$action" = created ]; then
        added="$(cat "$cwd/$rel" 2>/dev/null)"
      else
        added=""
      fi
      printf '%s' "$added" | grep -Eq "$CHAT_INIT_RE" && init_file="$rel"
    done < <(printf '%s' "$block" | jq -r '(.changes // []) | if type == "array" then .[] else empty end | objects
      | select(.action != "deleted") | [.path, .action] | map(strings) | select(length == 2) | @tsv' 2>/dev/null)
    if [ -n "$init_file" ] && [ "$named" -eq 0 ]; then
      problems="${problems}${problems:+$'\n'}this run added Chat SDK init code in $init_file without the $t_plat $t_host template: no changed file uses a name the templates in $t_dir declare ($(printf '%s' "$markers" | paste -sd ',' - | sed 's/,/, /g')); a source comment that names the template is not the template. The platform agent splices the verified template instead of writing its own init, connect, and observers: have it rewrite that code from the one of those templates that fits the request, keeping the template's types and functions under their names and its source comments, and call them from the app's own sign-in, then report again"
    fi
  fi
fi
# a clean answer ends the chain, so its record goes
[ -n "$problems" ] || { [ -n "$mark" ] && rm -f "$mark"; exit 0; }

# problem_kind <problem> : the kind a problem counts as when deciding whether it was sent back already
problem_kind() {
  case "$1" in
    *"asks for a bundler, env loader"*) echo appid-env-step ;;
    *"about building or type-checking"*) echo build-step ;;
    *"asks the customer to call"*) echo helper-handoff ;;
    *"init code in "*" template"*) echo template ;;
    *"lists no checks"*) echo no-checks ;;
    *"already asks to apply the fix"*) echo apply-consent ;;
    "the answer does not end with"*|"the last json block is not"*) echo no-summary ;;
    *) echo schema ;;
  esac
}
# sent_kind <kind> : 0 when a block in this stop chain already sent that kind back. The record keeps
# one line per block, each listing that block's kinds separated by commas.
sent_kind() { tr ',' '\n' < "$mark" 2>/dev/null | grep -Fxq "$1"; }
if [ "$active" = "true" ]; then
  [ "$(wc -l < "$mark" | tr -d ' ')" -ge 2 ] && exit 0
  fresh=""
  while IFS= read -r p; do
    [ -n "$p" ] && ! sent_kind "$(problem_kind "$p")" && fresh="$fresh$p"$'\n'
  done <<< "$problems"
  problems="$fresh"
  [ -n "$problems" ] || exit 0
fi
kinds="$(while IFS= read -r p; do [ -n "$p" ] && problem_kind "$p"; done <<< "$problems" | sort -u | paste -sd , -)"
if [ "$active" = "true" ]; then
  # fail open: a stop after a block that cannot be recorded passes, so it cannot loop
  printf '%s\n' "$kinds" >> "$mark" 2>/dev/null || exit 0
elif [ -n "$mark" ]; then
  # a stop that does not follow a block starts a new chain
  { printf '%s\n' "$kinds" > "$mark"; } 2>/dev/null
fi
problems="$(printf '%s' "$problems" | awk 'NF { printf "%s%s", (n++ ? "; " : ""), $0 }')"

jq -n --arg p "$problems" '{decision: "block",
  reason: ("Run summary check (Sendbird Client plugin, non-interactive run): " + $p + ". Write the whole answer again as the reply itself (the caller may see only this reply, so do not say it is repeated or mention this check), and end it with one fenced json block that validates against core/schemas/run-summary.schema.json: schemaVersion \"1\", skill (the skill name), status (completed, needs_input, failed, or declined), changes ([{path, action: created|modified|deleted, summary?}]), manualSteps (strings), plus questions for needs_input or reason for failed/declined, and optionally project, steps, apis, checks ([{name, result: pass|warn|fail|not_run|not_verified, detail?}]), and nextSteps (strings). No other fields. This check is not a reason to apply a change that waits for a yes from the customer: when the request did not ask to apply it, keep the files as they are and use needs_input with that yes/no question (docs/AGENT_CONTRACT.md section 7).")}'
exit 0
