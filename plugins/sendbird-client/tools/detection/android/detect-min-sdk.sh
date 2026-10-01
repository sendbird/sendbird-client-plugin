#!/usr/bin/env bash
# Detect Android minSdk, e.g. "24".
set -euo pipefail
dir="${1:?usage}"
v="$(find "$dir" \( -name 'build.gradle' -o -name 'build.gradle.kts' \) -not -path '*/.git/*' 2>/dev/null \
  | xargs grep -hoE 'minSdk(Version)?[[:space:]]*[=(]?[[:space:]]*[0-9]+' 2>/dev/null \
  | grep -oE '[0-9]+' | head -1)"
[ -n "$v" ] && { echo "$v"; exit 0; }
echo unknown
