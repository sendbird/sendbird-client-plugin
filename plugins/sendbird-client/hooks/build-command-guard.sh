#!/usr/bin/env bash
# PreToolUse guard: while the plugin's skills or agents work on the customer's project, a command that
# builds, compiles, or type-checks that project is denied, as docs/AGENT_CONTRACT.md section 3 says
# ("This run does not build, compile, or type-check the project"). Agents kept running
# `npm run typecheck` despite that line (a 2026-10 TC run: four runs failed on it).
#
# - Skill / Agent (Claude Code): a call of one of this plugin's skills or agents marks the session as
#   plugin work. Nothing is ever denied for these tools.
# - Bash (Claude Code and Codex, tool_input.command as a string or an argument list): a command that
#   names the plugin's folder (its tools, scripts, or a SKILL.md it reads, which is how Codex runs a
#   skill) also marks the session, and the parts of it that name that folder are always allowed (each part
#   between ; && || | is checked on its own): the plugin's own scripts, the run-check runner
#   tools/runtime/run.sh among them, build only when the customer agreed. Any other command is denied
#   when the session is plugin work, the latest request did not ask for a build (hooks/session-state.sh
#   prompt writes build-asked-<session_id> then), and a part of the command is a build (below).
# Without a session_id there is no state to read, and the guard allows everything.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

ROOT="$(plugin_root_real)"
plugin_name="$(jq -r '.name // empty' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null)"
mark_plugin_work() {
  local f
  f="$(session_state_file plugin-work)"
  [ -n "$f" ] || return 0
  mkdir -p "$(dirname "$f")" 2>/dev/null && umask 077 && : > "$f"
}

tool="$(jget .tool_name)"
case "$tool" in
  Skill|Agent|Task)
    name="$(jget .tool_input.skill)"; [ -n "$name" ] || name="$(jget .tool_input.subagent_type)"
    if [ -n "$plugin_name" ] && [ "${name%%:*}" = "$plugin_name" ]; then mark_plugin_work; fi
    exit 0 ;;
  Bash) ;;
  *) exit 0 ;;
esac

cmd="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.command | if type == "array" then join(" ") else (. // "") end' 2>/dev/null)"
[ -n "$cmd" ] || exit 0

# names_plugin <text> : 0 when the text names the plugin's own folder
names_plugin() {
  printf '%s' "$1" | grep -qF 'CLAUDE_PLUGIN_ROOT' \
    || { [ -n "$ROOT" ] && printf '%s' "$1" | grep -qF "$ROOT"; } \
    || { [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && printf '%s' "$1" | grep -qF "$CLAUDE_PLUGIN_ROOT"; }
}
# A command that names the plugin's folder makes the session plugin work from here on. Only the parts
# of the command that name it (the plugin's own scripts) are exempt below; another part of the same
# command is checked like any command ("cd <plugin>/x && npm run typecheck" ran in a 2026-10 TC run
# because the whole command was let through).
names_plugin "$cmd" && mark_plugin_work

work="$(session_state_file plugin-work)"
[ -n "$work" ] && [ -f "$work" ] || exit 0
asked="$(session_state_file build-asked)"
[ -n "$asked" ] && [ -f "$asked" ] && exit 0

# build_part <command> : prints the first part of the command that builds the project. Heredoc bodies
# are file contents, not commands; quotes, backticks, and $( ) become spaces, so bash -c "..." reads as
# plain words; each part between ; && || | and newlines is checked on its own, after its env assignments
# and wrapper words (env, time, exec, command, nohup, sudo, npx, bunx, pnpm dlx, bash -c, bash -lc).
build_part() {
  printf '%s\n' "$1" | awk '
    end != "" { if ($0 ~ "^[[:space:]]*" end "[[:space:]]*$") end = ""; next }
    { print; if (match($0, /<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) { w = substr($0, RSTART, RLENGTH); gsub(/^<<-?[[:space:]]*["\047]?/, "", w); end = w } }' \
  | tr "\"'\`()" '     ' | sed -E 's/\$/ /g; s/(&&|\|\||;|\|)/\n/g' \
  | while IFS= read -r part; do
      names_plugin "$part" && continue
      p="$(printf '%s' "$part" | sed -E 's/^[[:space:]]+//; s/^(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|time|exec|command|nohup|sudo|npx|bunx|pnpm dlx|--no-install|-y|--yes|bash|sh|zsh|-[a-z]*c)[[:space:]]+)+//')"
      case "$p" in
        xcodebuild*|*/xcodebuild*)
          printf '%s' "$p" | grep -Eq '(^|[[:space:]])-(version|list|showsdks|showBuildSettings|showdestinations|resolvePackageDependencies|help)([[:space:]]|$)' && continue ;;
        gradle*|gradlew*|./gradlew*|*/gradlew*)
          printf '%s' "$p" | grep -Eq '^[^[:space:]]*gradlew?(\.bat)?([[:space:]]+-[^[:space:]]+)*([[:space:]]+(dependencies|tasks|help|properties|--version|-v|--stop|:[A-Za-z0-9_:-]*dependencies))*[[:space:]]*$' && continue ;;
      esac
      if printf '%s' "$p" | grep -Eq '^([^[:space:]]*/)?(xcodebuild|xcodegen|tsc|gradlew?(\.bat)?)([[:space:]]|$)|^swift[[:space:]]+(build|test)([[:space:]]|$)|^(npm|yarn|pnpm|bun)[[:space:]]+(run[[:space:]]+)?(build|typecheck|type-check|tsc|compile)([[:space:]:]|$)|^([^[:space:]]*/)?(vite|next|webpack|react-scripts)[[:space:]]+build([[:space:]]|$)'; then
        printf '%s' "$p" | cut -c1-160
        return 0
      fi
    done
}

hit="$(build_part "$cmd")"
[ -n "$hit" ] || exit 0

jq -n --arg c "$hit" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("This run does not build, compile, or type-check the project (docs/AGENT_CONTRACT.md section 3), and the customer did not ask for a build: " + $c + "\nDo not run it or a variant of it. Check each Sendbird symbol against the installed SDK surface or the cited curated section instead; the plugin'"'"'s own test suites build the code it emits. If a build is needed, say so in the answer; the run-check skill builds and runs the app when the customer asks.")
  }
}'
exit 0
