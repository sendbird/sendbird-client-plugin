#!/usr/bin/env bash
# Tier-2 best-effort: state-management library.
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
file_contains "$dir" "*.swift" 'import[[:space:]]+Combine' && { echo combine; exit 0; }
file_contains "$dir" "*.swift" 'import[[:space:]]+RxSwift' && { echo rxswift; exit 0; }
file_contains "$dir" "*.kt" 'kotlinx\.coroutines\.flow' && { echo coroutines-flow; exit 0; }
if [ -f "$dir/package.json" ]; then
  pkgjson_has_dep "$dir" "@reduxjs/toolkit" && { echo redux; exit 0; }
  pkgjson_has_dep "$dir" "zustand" && { echo zustand; exit 0; }
  pkgjson_has_dep "$dir" "mobx" && { echo mobx; exit 0; }
fi
echo unknown
