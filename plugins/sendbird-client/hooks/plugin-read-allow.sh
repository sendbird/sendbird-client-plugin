#!/usr/bin/env bash
# PreToolUse hook (Read, Grep, Glob, Bash): approves reading the plugin's own installed files, and running its
# read-only scripts, without a prompt.
# In a 2026-11 audit, a customer in the default permission mode answered 19 to 21 prompts in one setup run,
# many of them for the plugin reading its own contract, skills, and curated docs from its install folder,
# which is outside the project. A plugin cannot ship permission rules, and a skill's allowed-tools do not
# reach the agents it starts, so this hook answers "allow" for a read whose every path is inside the plugin
# folder (symlinks resolved; a file that is itself a symlink does not count). Anything else it leaves to the
# customer's own permission rules: it prints nothing. It never approves a write, and a deny or ask rule of the
# customer's still wins over its allow.
# A shell command is approved only when it is one or more calls of the read-only scripts below, by their path in
# the plugin folder, with plain or quoted arguments, joined by ";", "&&", or a new line (an "echo '<label>'"
# between them is fine). Those scripts read the project, the plugin's index, or a public registry, and write only
# in the plugin's state folder in the project. A pipe, a redirect, a variable, a command substitution, any other
# command, or a secret in the command (core/commands/check-credential.sh) leaves it to the customer. The scripts
# that run other tools (tools/verify/check-written.sh runs the project's type checker, tools/runtime/run.sh
# installs and starts the app) are not in the list.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/hook-helpers.sh
source "$HERE/lib/hook-helpers.sh"
read_stdin_json

root="$(plugin_root_real)"
[ -n "$root" ] && [ "$root" != / ] || exit 0

# inside_plugin <path> : 0 when the path, with its folders' symlinks resolved, is the plugin folder or in it
inside_plugin() {
  local p="$1" d b real
  case "$p" in /*) ;; *) return 1 ;; esac
  case "/$p/" in */../*|*/./*) return 1 ;; esac
  if [ -d "$p" ]; then real="$(cd "$p" 2>/dev/null && pwd -P)" || return 1
  else
    [ -L "$p" ] && return 1
    d="$(dirname "$p")"; b="$(basename "$p")"
    real="$(cd "$d" 2>/dev/null && pwd -P)/$b" || return 1
  fi
  case "$real" in "$root"|"$root"/*) return 0 ;; *) return 1 ;; esac
}

# read_only_script_call <command> : 0 when the command is only calls of the read-only plugin scripts
read_only_script_call() {
  local cmd="$1" r roots="" esc nl=$'\n'
  # every script below is under tools/ or core/commands/ (checked before the regular expressions are built)
  case "$cmd" in *tools/*.sh*|*core/commands/*.sh*) ;; *) return 1 ;; esac
  for r in "$root" "${CLAUDE_PLUGIN_ROOT:-}"; do
    [ -n "$r" ] || continue
    esc="$(printf '%s' "${r%/}" | sed 's/[][\.*^$+?(){}|]/\\&/g')"
    roots="${roots:+$roots|}$esc"
  done
  local scripts='tools/detection/(detect|resolve-products|resolve-app-id)|tools/routing/route-agent|tools/local-sdk/(read-surface|latest-version|deprecated-usage)|core/commands/(search|search-discussions|fetch-doc)'
  local path="($roots)/($scripts)\.sh"
  local dq='"[^"$`\\]*"' sq="'[^']*'" plain='[A-Za-z0-9_./@:=,+%-]+'
  local arg="($plain|$dq|$sq)" ws='[ 	]'
  local call="(bash|sh)$ws+($path|\"$path\"|'$path')($ws+$arg)*"
  local label="echo$ws+($sq|$dq|$plain)"
  local seg="$ws*($call|$label)$ws*"
  [[ "$cmd" =~ ^$seg((\;|\&\&|$nl)$seg)*\;?$ws*$ ]] || return 1
  [[ "$cmd" =~ (^|[;&$nl])$ws*$call ]] || return 1
  may_hold_credential "$cmd" || return 0
  [ -z "$(printf '%s' "$cmd" | bash "$HERE/../core/commands/check-credential.sh" 2>/dev/null | jq -r '.hit // empty')" ]
}

case "$(jget '.tool_name')" in
  Read) inside_plugin "$(jget '.tool_input.file_path')" || exit 0 ;;
  Grep) inside_plugin "$(jget '.tool_input.path')" || exit 0 ;;
  Glob)
    inside_plugin "$(jget '.tool_input.path')" || exit 0
    case "$(jget '.tool_input.pattern')" in /*|*..*) exit 0 ;; esac ;;
  Bash) read_only_script_call "$(jget '.tool_input.command')" || exit 0 ;;
  *) exit 0 ;;
esac

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow",
  permissionDecisionReason: "Sendbird Client Plugin: reading its own installed files or running its read-only scripts"}}'
exit 0
