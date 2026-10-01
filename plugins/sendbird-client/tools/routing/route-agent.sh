#!/usr/bin/env bash
# Resolve one plugin agent from the detected project platform and task kind.
set -euo pipefail
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
platform="$(jq -r '.platform // "unknown"' "$dir/.sendbird-client/profile.json")"
agent="$(jq -r --arg platform "$platform" '.routing.code[$platform] // empty' "$config")"
[ -n "$agent" ] || { echo "no code agent for detected platform: $platform" >&2; exit 1; }
printf '%s\n' "$agent"
