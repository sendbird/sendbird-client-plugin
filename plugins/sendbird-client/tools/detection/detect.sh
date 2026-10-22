#!/usr/bin/env bash
# Tier-1 detection orchestrator. Writes <project>/.sendbird-client/profile.json (spec §11.3).
#
# Thin plugin-side wrapper around core/commands/detect.sh (the pure, side-effect-free
# detector). This script owns the ONE thing the core command deliberately doesn't:
# deciding what gets persisted. It merges the fresh detection result onto whatever is
# already stored, so any previously stored field the fresh detection doesn't itself
# produce (appId today; any future customer-set field) survives re-detection instead
# of being silently discarded. See core/README.md.
set -euo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
dir="${1:?usage: detect.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "$HERE/../../core/commands" && pwd)"

fresh="$(bash "$CORE/detect.sh" "$dir")"

mkdir -p "$dir/.sendbird-client"
prof="$dir/.sendbird-client/profile.json"
stored="$(cat "$prof" 2>/dev/null || echo '{}')"
printf '%s' "$stored" | jq -e . >/dev/null 2>&1 || stored='{}'

# Stored fields survive; fresh detection overwrites only the keys it actually produces.
jq -n --argjson stored "$stored" --argjson fresh "$fresh" '$stored + $fresh' > "$prof"
echo "wrote $prof"
