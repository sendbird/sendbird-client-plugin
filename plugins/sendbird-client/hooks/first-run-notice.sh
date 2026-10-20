#!/usr/bin/env bash
# SessionStart hook (Claude Code): show the customer, once, what this plugin runs on their machine.
# A customer whose AI tool installed the plugin may never have opened the README, where this notice
# lives. systemMessage is shown to the user and not passed to the model (welcome.sh's plain stdout is
# model context only). The notice is shown again only when its text changes. Never blocks.
set -uo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=lib/hook-helpers.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/hook-helpers.sh"
MANIFEST="$ROOT/.claude-plugin/plugin.json"
field() { # $1 = manifest key; jq when present, else the plain "key": "value" line
  if command -v jq >/dev/null 2>&1; then jq -r --arg k "$1" '.[$k] // empty' "$MANIFEST" 2>/dev/null
  else sed -n "s/^[[:space:]]*\"$1\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$MANIFEST" 2>/dev/null | head -1; fi
}
name="$(field name)"; display="$(field displayName)"; repo="$(field repository)"
[ -n "$name" ] || exit 0
msg="${display:-$name} plugin: this plugin runs shell scripts on your computer with your user account's permissions, at session start, before file writes and shell commands, after an agent finishes, and when an answer ends. They read your project files and parts of this conversation, can block an action or ask Claude to revise its answer, and fetch public pages from sendbird.com/docs and github.com/sendbird. Nothing from your project or conversation is sent to Sendbird. A plugin update replaces these scripts; auto-update is off unless you turn it on. Details: ${repo}#what-runs-on-your-machine (shown once, and again if this notice changes)"
# The shown mark lives in the plugin's data folder, which Claude Code keeps across plugin updates.
data="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/$name}"
mark="$data/first-run-notice"
sum="$(printf '%s' "$msg" | cksum | cut -d' ' -f1)"
[ "$(cat "$mark" 2>/dev/null)" = "$sum" ] && exit 0
# A run nobody watches (SENDBIRD_NONINTERACTIVE) shows it without marking it shown, so the customer
# still sees it in their first interactive session.
is_noninteractive || { mkdir -p "$data" 2>/dev/null && printf '%s\n' "$sum" > "$mark" 2>/dev/null; }
if command -v jq >/dev/null 2>&1; then jq -n --arg m "$msg" '{systemMessage: $m}'
else printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')"; fi
exit 0
