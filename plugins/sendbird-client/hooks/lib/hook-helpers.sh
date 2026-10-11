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
