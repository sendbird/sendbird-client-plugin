#!/usr/bin/env bash
# Resolve one plugin agent from the detected project platform and task kind.
set -euo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
dir="${1:?usage: route-agent.sh <project-dir> [code|docs]}"
kind="${2:-code}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
config="$ROOT/config/plugin-config.json"

case "$kind" in
  docs) jq -er '.routing.docs' "$config"; exit 0 ;;
  code) ;;
  *) echo "unknown task kind: $kind" >&2; exit 1 ;;
esac

bash "$ROOT/tools/detection/detect.sh" "$dir" >/dev/null
# an empty folder gets no profile (detect.sh): its platform is unknown
platform="$(jq -r '.platform // "unknown"' "$dir/.sendbird-client/profile.json" 2>/dev/null || echo unknown)"
agent="$(jq -r --arg platform "$platform" '.routing.code[$platform] // empty' "$config")"
[ -n "$agent" ] || { echo "no code agent for detected platform: $platform" >&2; exit 1; }
printf '%s\n' "$agent"
