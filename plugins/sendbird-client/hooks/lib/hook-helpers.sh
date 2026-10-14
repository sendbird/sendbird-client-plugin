#!/usr/bin/env bash
# Shared helpers for hook scripts. Source this file. Reads stdin JSON once.

# read_stdin_json : caches the stdin payload into $HOOK_JSON (empty if none/not json)
read_stdin_json() {
  HOOK_JSON="$(cat 2>/dev/null || true)"
  if ! printf '%s' "$HOOK_JSON" | jq -e . >/dev/null 2>&1; then HOOK_JSON='{}'; fi
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
