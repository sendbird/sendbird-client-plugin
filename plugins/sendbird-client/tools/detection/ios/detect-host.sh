#!/usr/bin/env bash
# Detect iOS host UI: swiftui | uikit | hybrid | unknown
set -euo pipefail
dir="${1:?usage: detect-host.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
swiftui=0; uikit=0
file_contains "$dir" "*.swift" '(struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*App\b|:[[:space:]]*View\b|import[[:space:]]+SwiftUI)' && swiftui=1
{ has_glob "$dir" "*.storyboard" "*.xib" || file_contains "$dir" "*.swift" '(UIApplicationDelegate|UIResponder|import[[:space:]]+UIKit)'; } && uikit=1
if [ "$swiftui" -eq 1 ] && [ "$uikit" -eq 1 ]; then echo hybrid; exit 0; fi
[ "$swiftui" -eq 1 ] && { echo swiftui; exit 0; }
[ "$uikit" -eq 1 ] && { echo uikit; exit 0; }
echo unknown
