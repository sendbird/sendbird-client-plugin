#!/usr/bin/env bash
# Tier-1 detection orchestrator. Writes <project>/.sendbird-client/profile.json (spec §11.3),
# except in an empty folder that has no profile yet.
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
prof="$dir/.sendbird-client/profile.json"

# An empty folder (only hidden entries such as .git) with no profile yet, as before new-app setup, has
# nothing to store: creating a profile there would be a change in a run that must change nothing
# (a needs_input stop, docs/AGENT_CONTRACT.md section 7). New-app setup writes it once it has files.
if [ ! -f "$prof" ] && [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name '.*' 2>/dev/null | head -1)" ]; then
  echo "empty folder $dir: no project detected, profile not written"
  exit 0
fi

mkdir -p "$dir/.sendbird-client"
stored="$(cat "$prof" 2>/dev/null || echo '{}')"
printf '%s' "$stored" | jq -e . >/dev/null 2>&1 || stored='{}'

# Stored fields survive; fresh detection overwrites only the keys it actually produces.
jq -n --argjson stored "$stored" --argjson fresh "$fresh" '$stored + $fresh' > "$prof"
echo "wrote $prof"
