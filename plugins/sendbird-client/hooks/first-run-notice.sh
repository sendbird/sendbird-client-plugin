#!/usr/bin/env bash
# Show the customer, once, what this plugin runs on their machine. A customer whose AI tool installed
# the plugin may never have opened the README, where this notice lives. systemMessage is shown to the
# user and not passed to the model (welcome.sh's plain stdout is model context only). The notice is
# shown again only when its text changes. Never blocks.
#
# Usage: first-run-notice.sh [start|prompt|tool]   (the hook event; default start)
# It runs at session start, and again before the first prompt and the first tool call until it is
# marked shown: a plugin installed inside a running session (/plugin) skips that session's start, and
# the VS Code extension does not show a session-start systemMessage (it shows prompt and tool ones).
#   start          marks it shown only in the terminal (CLAUDE_CODE_ENTRYPOINT cli) or when the host
#                  does not say (Codex, older Claude Code); elsewhere a later prompt shows and marks it.
#   prompt, tool   shows and marks it.
# A run nobody watches (SENDBIRD_NONINTERACTIVE, or CLAUDE_CODE_ENTRYPOINT sdk-*: `claude -p` and Agent
# SDK programs) shows it at session start only and never marks it, so the customer still sees it in
# their first interactive session. CLAUDE_CODE_ENTRYPOINT is not documented: when it is missing, the
# notice behaves as it did before this variable was read.
set -uo pipefail
event="${1:-start}"
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=lib/hook-helpers.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/hook-helpers.sh"
entry="${CLAUDE_CODE_ENTRYPOINT:-}"
unwatched=0; { is_noninteractive || case "$entry" in sdk-*) true ;; *) false ;; esac; } && unwatched=1
[ "$event" != start ] && [ "$unwatched" -eq 1 ] && exit 0
MANIFEST="$ROOT/.claude-plugin/plugin.json"
field() { # $1 = manifest key; jq when present, else the plain "key": "value" line
  if command -v jq >/dev/null 2>&1; then jq -r --arg k "$1" '.[$k] // empty' "$MANIFEST" 2>/dev/null
  else sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$MANIFEST" 2>/dev/null | head -1; fi
}
name="$(field name)"; display="$(field displayName)"; repo="$(field repository)"
[ -n "$name" ] || exit 0
msg="${display:-$name} plugin: this plugin runs shell scripts on your computer with your user account's permissions, at session start, before file writes and shell commands, after an agent finishes, and when an answer ends. They read your project files and parts of this conversation, can block an action or ask Claude to revise its answer, and fetch public pages from sendbird.com/docs and github.com/sendbird. Nothing from your project or conversation is sent to Sendbird. A plugin update replaces these scripts; auto-update is off unless you turn it on. Details: ${repo}#what-runs-on-your-machine (shown once, and again if this notice changes)"
# The shown mark lives in the plugin's data folder, which Claude Code and Codex keep across plugin updates.
data="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/$name}"
mark="$data/first-run-notice"
sum="$(printf '%s' "$msg" | cksum | cut -d' ' -f1)"
[ "$(cat "$mark" 2>/dev/null)" = "$sum" ] && exit 0
marks=1
[ "$unwatched" -eq 1 ] && marks=0
[ "$event" = start ] && case "$entry" in ""|cli) ;; *) marks=0 ;; esac
[ "$marks" -eq 1 ] && { mkdir -p "$data" 2>/dev/null && printf '%s\n' "$sum" > "$mark" 2>/dev/null; }
if command -v jq >/dev/null 2>&1; then jq -n --arg m "$msg" '{systemMessage: $m}'
else printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"; fi
exit 0
