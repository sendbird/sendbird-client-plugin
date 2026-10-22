#!/usr/bin/env bash
# Stop hook for non-interactive runs (SENDBIRD_NONINTERACTIVE=1, true, or yes): the caller, a CLI or a
# script, decides what to do next from the run summary the answer ends with, so its shape is
# checked before the run ends. A follow-up request sent with --resume does not get the
# session-start instructions again, and such a run once ended with "status": "ok" and no
# schemaVersion/skill. On a problem, block once and say what is wrong; the documented
# stop_hook_active guard lets the second stop pass, so this cannot loop. Interactive
# sessions are not checked. Fail open when the schema or the answer cannot be read.
# A completed run that changed app files must also list its checks (docs/AGENT_CONTRACT.md sections 4
# and 6); the block asks for the whole answer again, since a run once re-sent only the json block.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

is_noninteractive || exit 0
[ "$(jget '.stop_hook_active')" = "true" ] && exit 0
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

# the last ```json fenced block of the answer
block="$(printf '%s\n' "$text" | awk '/^[[:space:]]*```json[[:space:]]*$/ {on=1; buf=""; next}
  on && /^[[:space:]]*```[[:space:]]*$/ {on=0; last=buf; next} on {buf = buf $0 "\n"} END {printf "%s", last}')"

if [ -z "$block" ]; then
  problems="the answer does not end with a fenced json run summary"
elif ! printf '%s' "$block" | jq -e 'type == "object"' >/dev/null 2>&1; then
  problems="the last json block is not a JSON object"
else
  problems="$(printf '%s' "$block" | jq -r --slurpfile s "$SCHEMA" --arg build "$build_step" --arg sd "$state_dir" '
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
        (if $d.status == "needs_input" and (($d.questions // []) | length) == 0 then "needs_input needs at least one questions entry" else empty end),
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
      ] | unique | join("; ")' 2>/dev/null)" || exit 0
fi
[ -n "$problems" ] || exit 0

jq -n --arg p "$problems" '{decision: "block",
  reason: ("Run summary check (Sendbird plugin, non-interactive run): " + $p + ". Write the whole answer again as the reply itself (the caller may see only this reply, so do not say it is repeated or mention this check), and end it with one fenced json block that validates against core/schemas/run-summary.schema.json: schemaVersion \"1\", skill (the skill name), status (completed, needs_input, failed, or declined), changes ([{path, action: created|modified|deleted, summary?}]), manualSteps (strings), plus questions for needs_input or reason for failed/declined, and optionally project, steps, apis, checks ([{name, result: pass|warn|fail|not_run|not_verified, detail?}]), and nextSteps (strings). No other fields. This check is not a reason to apply a change that waits for a yes from the customer: when the request did not ask to apply it, keep the files as they are and use needs_input with that yes/no question (docs/AGENT_CONTRACT.md section 7).")}'
exit 0
