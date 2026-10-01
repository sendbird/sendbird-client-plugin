#!/usr/bin/env bash
# Detect Sendbird region. Sources ONLY: SENDBIRD_REGION env, or region in
# <dir>/.sendbird-client/profile.json. Never guessed. Defaults to "default".
set -euo pipefail
dir="${1:?usage}"
if [ -n "${SENDBIRD_REGION:-}" ]; then echo "$SENDBIRD_REGION"; exit 0; fi
prof="$dir/.sendbird-client/profile.json"
if [ -f "$prof" ]; then
  r="$(jq -r '.region // empty' "$prof" 2>/dev/null)"
  [ -n "$r" ] && { echo "$r"; exit 0; }
fi
echo "default"
