#!/usr/bin/env bash
# Stop hook for non-interactive runs (SENDBIRD_NONINTERACTIVE set): the caller, a CLI or a
# script, decides what to do next from the run summary the answer ends with, so its shape is
# checked before the run ends. A follow-up request sent with --resume does not get the
# session-start instructions again, and such a run once ended with "status": "ok" and no
# schemaVersion/skill. On a problem, block once and say what is wrong; the documented
# stop_hook_active guard lets the second stop pass, so this cannot loop. Interactive
# sessions are not checked. Fail open when the schema or the answer cannot be read.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

[ -n "${SENDBIRD_NONINTERACTIVE:-}" ] || exit 0
[ "$(jget '.stop_hook_active')" = "true" ] && exit 0
SCHEMA="${CLAUDE_PLUGIN_ROOT:-$HERE/..}/core/schemas/run-summary.schema.json"
[ -r "$SCHEMA" ] || exit 0

text="$(final_answer_text)"
[ -n "$text" ] || exit 0

# the last ```json fenced block of the answer
block="$(printf '%s\n' "$text" | awk '/^[[:space:]]*```json[[:space:]]*$/ {on=1; buf=""; next}
  on && /^[[:space:]]*```[[:space:]]*$/ {on=0; last=buf; next} on {buf = buf $0 "\n"} END {printf "%s", last}')"

if [ -z "$block" ]; then
  problems="the answer does not end with a fenced json run summary"
elif ! printf '%s' "$block" | jq -e 'type == "object"' >/dev/null 2>&1; then
  problems="the last json block is not a JSON object"
else
  problems="$(printf '%s' "$block" | jq -r --slurpfile s "$SCHEMA" '
    ($s[0]) as $S | . as $d
    | ($S.properties.status.enum) as $st
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
        (if $d.status == "needs_input" and (($d.questions // []) | length) == 0 then "needs_input needs at least one questions entry" else empty end),
        (if $d.status == "needs_input" and (($d.changes // []) | length) > 0 then "needs_input must not list changes" else empty end),
        (if ($d.status | IN("failed","declined")) and ((($d.reason // "") | type) != "string" or ($d.reason // "") == "") then "\($d.status) needs a reason" else empty end)
      ] | unique | join("; ")' 2>/dev/null)" || exit 0
fi
[ -n "$problems" ] || exit 0

jq -n --arg p "$problems" '{decision: "block",
  reason: ("Run summary check (Sendbird plugin, non-interactive run): " + $p + ". End the answer with one fenced json block that validates against core/schemas/run-summary.schema.json: schemaVersion \"1\", skill (the skill name), status (completed, needs_input, failed, or declined), changes ([{path, action: created|modified|deleted, summary?}]), manualSteps (strings), plus questions for needs_input or reason for failed/declined. No other fields.")}'
exit 0
