#!/usr/bin/env bash
# Detect iOS host UI: swiftui | uikit | hybrid | unknown
# hybrid means a UIKit app (its entry point is a UIApplicationDelegate) that also has SwiftUI views.
# A SwiftUI App entry stays swiftui when it uses UIKit only inside SwiftUI: an AppDelegate attached
# through @UIApplicationDelegateAdaptor, UIColor or UIImage imports, or UIKit screens wrapped in
# UIViewControllerRepresentable (detect-interop.sh reports that as uikit-in-swiftui).
set -euo pipefail
dir="${1:?usage: detect-host.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"

# uikit_entry <dir> : 0 if the app's entry point is UIKit — a @main / @UIApplicationMain file that
# declares a UIApplicationDelegate (not the SwiftUI adaptor), a UIApplicationMain(...) call in
# main.swift, or a storyboard other than the launch screen.
uikit_entry() {
  local d="$1"
  find "$d" -type f -name '*.swift' -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null \
    | xargs -0 grep -lE '^[[:space:]]*@(main|UIApplicationMain)([^A-Za-z0-9_]|$)' 2>/dev/null \
    | tr '\n' '\0' | xargs -0 grep -lE 'UIApplicationDelegate([^A-Za-z0-9_]|$)' 2>/dev/null | grep -q . && return 0
  file_contains "$d" "*.swift" '(^|[^A-Za-z0-9_.])UIApplicationMain[[:space:]]*\(' && return 0
  find "$d" -type f -name '*.storyboard' -not -name 'LaunchScreen.storyboard' \
    -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | grep -q .
}

swiftui=0; uikit=0
file_contains "$dir" "*.swift" '(struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*App\b|:[[:space:]]*View\b|import[[:space:]]+SwiftUI)' && swiftui=1
{ has_glob "$dir" "*.storyboard" "*.xib" || file_contains "$dir" "*.swift" '(UIApplicationDelegate|UIResponder|import[[:space:]]+UIKit)'; } && uikit=1
if [ "$swiftui" -eq 1 ] && [ "$uikit" -eq 1 ]; then
  if file_contains "$dir" "*.swift" 'struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*App\b' && ! uikit_entry "$dir"; then
    echo swiftui; exit 0
  fi
  echo hybrid; exit 0
fi
[ "$swiftui" -eq 1 ] && { echo swiftui; exit 0; }
[ "$uikit" -eq 1 ] && { echo uikit; exit 0; }
echo unknown
