#!/usr/bin/env bash
# Detect Android host UI: compose | view | hybrid | unknown
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
compose=0; view=0
{ file_contains "$dir" "*.kt" '(@Composable|setContent[[:space:]]*\{|androidx\.compose)' \
  || file_contains "$dir" "*.gradle.kts" 'compose[[:space:]]*=[[:space:]]*true' \
  || file_contains "$dir" "*.gradle" 'compose true'; } && compose=1
{ has_glob "$dir" "*.xml" && file_contains "$dir" "*.xml" '<(LinearLayout|RelativeLayout|ConstraintLayout|FrameLayout|androidx)'; } && view=1
if [ "$compose" -eq 1 ] && [ "$view" -eq 1 ]; then echo hybrid; exit 0; fi
[ "$compose" -eq 1 ] && { echo compose; exit 0; }
[ "$view" -eq 1 ] && { echo view; exit 0; }
echo unknown
