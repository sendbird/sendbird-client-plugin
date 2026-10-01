#!/usr/bin/env bash
# Detect JS host: react-native | react | hybrid | unknown
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
rn=0; web=0
pkgjson_has_dep "$dir" "react-native" && rn=1
{ pkgjson_has_dep "$dir" "react-dom" || pkgjson_has_dep "$dir" "next"; } && web=1
if [ "$rn" -eq 1 ] && [ "$web" -eq 1 ]; then echo hybrid; exit 0; fi
[ "$rn" -eq 1 ] && { echo react-native; exit 0; }
[ "$web" -eq 1 ] && { echo react; exit 0; }
echo unknown
