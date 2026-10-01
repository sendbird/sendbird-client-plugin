#!/usr/bin/env bash
# Detect Gradle DSL flavor: kts | groovy | unknown
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
kts=0; groovy=0
has_glob "$dir" "build.gradle.kts" "settings.gradle.kts" && kts=1
has_glob "$dir" "build.gradle" "settings.gradle" && groovy=1
if [ "$kts" -eq 1 ] && [ "$groovy" -eq 0 ]; then echo kts; exit 0; fi
if [ "$groovy" -eq 1 ] && [ "$kts" -eq 0 ]; then echo groovy; exit 0; fi
if [ "$kts" -eq 1 ] && [ "$groovy" -eq 1 ]; then echo kts; exit 0; fi
echo unknown
