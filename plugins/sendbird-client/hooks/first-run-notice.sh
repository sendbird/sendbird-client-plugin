#!/usr/bin/env bash
# Show the customer, once, what this plugin runs on their machine. A customer whose AI tool installed
# the plugin may never have opened the README, where this notice lives. systemMessage is shown to the
# user and not passed to the model (welcome.sh's plain stdout is model context only). The notice is
# shown again only when its text changes. Never blocks.
#
# Usage: first-run-notice.sh [start|prompt|tool|text|script]   (the hook event; default start)
#   text   prints the notice's checksum on one line and its text on the next, for hooks/notice.js
#   script for the plugin's own scripts that skills run (tools/, core/commands/): until the notice is
#          marked shown, prints it to stderr and marks it. In Codex a skill can run these scripts
#          before the customer trusts the plugin's hooks, and the command's first output line is
#          what Codex shows, so that line is a short summary with the link. Silent when the plugin
#          is not in an installed plugin folder (a checkout, CI) and in runs nobody watches.
# It runs at session start, and again before the first prompt and the first tool call until it is
# marked shown: a plugin installed inside a running session (/plugin) skips that session's start, and
# the VS Code extension does not show a session-start systemMessage (it shows prompt and tool ones).
#   start          marks it shown only in the terminal (CLAUDE_CODE_ENTRYPOINT cli) or when the host
#                  does not say (Codex, older Claude Code); elsewhere a later prompt shows and marks it.
#   prompt, tool   shows and marks it.
# A run nobody watches (SENDBIRD_NONINTERACTIVE, or CLAUDE_CODE_ENTRYPOINT sdk-*: `claude -p` and Agent
# SDK programs) shows it at session start only and never marks it, so the customer still sees it in
# their first interactive session. The Desktop app (claude-desktop) draws no hook systemMessage at
# all, so there it is the same: session start only, never marked. CLAUDE_CODE_ENTRYPOINT is not
# documented: when it is missing, the notice behaves as it did before this variable was read.
# In the Desktop app and the VS Code extension, where Claude Code loads mods, hooks/notice.js draws
# the notice in the conversation instead and sets SENDBIRD_NOTICE_BY_MOD, which keeps this script
# quiet for the rest of the session.
set -uo pipefail
event="${1:-start}"
[ "$event" != text ] && [ -n "${SENDBIRD_NOTICE_BY_MOD:-}" ] && exit 0
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=lib/hook-helpers.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/hook-helpers.sh"
entry="${CLAUDE_CODE_ENTRYPOINT:-}"
unwatched=0; { is_noninteractive || case "$entry" in sdk-*|claude-desktop*) true ;; *) false ;; esac; } && unwatched=1
[ "$event" != start ] && [ "$event" != text ] && [ "$unwatched" -eq 1 ] && exit 0
MANIFEST="$ROOT/.claude-plugin/plugin.json"
field() { # $1 = manifest key; jq when present, else the plain "key": "value" line
  if command -v jq >/dev/null 2>&1; then jq -r --arg k "$1" '.[$k] // empty' "$MANIFEST" 2>/dev/null
  else sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$MANIFEST" 2>/dev/null | head -1; fi
}
name="$(field name)"; display="$(field displayName)"; repo="$(field repository)"
[ -n "$name" ] || exit 0
msg="${display:-$name} plugin: this plugin runs shell scripts on your computer with your user account's permissions, at session start, before file writes and shell commands, after an agent finishes, and when an answer ends. In Claude Code it also runs one JavaScript file that only shows this notice. They read your project files and parts of this conversation, can block an action or ask Claude to revise its answer, and fetch public pages from sendbird.com/docs and github.com/sendbird. Nothing from your project or conversation is sent to Sendbird. A plugin update replaces these scripts; auto-update is off unless you turn it on. Details: ${repo}#what-runs-on-your-machine (shown once, and again if this notice changes)"
# The shown mark lives in the plugin's data folder, which Claude Code and Codex keep across plugin updates.
# Hooks get CLAUDE_PLUGIN_DATA; a skill's shell command does not (Codex sets nothing there), so the same
# folder is found from where the plugin is installed: <home>/plugins/cache/<marketplace>/<plugin>/<version>
# keeps its data in <home>/plugins/data/<plugin>-<marketplace>.
installed_data() {
  local p="${ROOT%/}" plugin mkt
  p="${p%/*}"; plugin="${p##*/}"; p="${p%/*}"; mkt="${p##*/}"; p="${p%/*}"
  case "$p" in */plugins/cache) printf '%s/data/%s-%s\n' "${p%/cache}" "$plugin" "$mkt" ;; esac
}
# A skill's command can inherit CLAUDE_PLUGIN_DATA from the customer's shell, set there for another
# plugin, so script mode trusts only the install path.
if [ "$event" = script ]; then data="$(installed_data)"; [ -z "$data" ] && exit 0
else data="${CLAUDE_PLUGIN_DATA:-$(installed_data)}"; fi
data="${data:-$HOME/.claude/plugins/data/$name}"
mark="$data/first-run-notice"
sum="$(printf '%s' "$msg" | cksum | cut -d' ' -f1)"
[ "$event" = text ] && { printf '%s\n%s\n' "$sum" "$msg"; exit 0; }
[ "$(cat "$mark" 2>/dev/null)" = "$sum" ] && exit 0
# Codex's default sandbox lets a skill's command write only inside the project, so a script may fail to
# write the mark above; it then keeps it in the project's state folder, where detect.sh keeps profile.json.
local_mark=""
if [ "$event" = script ]; then
  state="$(jq -r '.stateDir // empty' "$ROOT/config/plugin-config.json" 2>/dev/null)"
  [ -n "$state" ] && local_mark="$PWD/$state/first-run-notice"
  [ -n "$local_mark" ] && [ "$(cat "$local_mark" 2>/dev/null)" = "$sum" ] && exit 0
fi
marks=1
[ "$unwatched" -eq 1 ] && marks=0
[ "$event" = start ] && case "$entry" in ""|cli) ;; *) marks=0 ;; esac
[ "$marks" -eq 1 ] && { { mkdir -p "$data" 2>/dev/null && printf '%s\n' "$sum" > "$mark" 2>/dev/null; } ||
  { [ -n "$local_mark" ] && mkdir -p "${local_mark%/*}" 2>/dev/null && printf '%s\n' "$sum" > "$local_mark" 2>/dev/null; }; }
[ "$event" = script ] && {
  printf '%s plugin runs local scripts on your computer. Details: %s#what-runs-on-your-machine\n%s\n' "${display:-$name}" "$repo" "$msg" >&2
  exit 0
}
if command -v jq >/dev/null 2>&1; then jq -n --arg m "$msg" '{systemMessage: $m}'
else printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"; fi
exit 0
