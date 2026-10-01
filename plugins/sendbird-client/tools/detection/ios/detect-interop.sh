#!/usr/bin/env bash
# Detect iOS host interop: uikit-in-swiftui | swiftui-in-uikit | none
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
file_contains "$dir" "*.swift" '(UIViewControllerRepresentable|UIViewRepresentable)' && { echo uikit-in-swiftui; exit 0; }
file_contains "$dir" "*.swift" 'UIHostingController' && { echo swiftui-in-uikit; exit 0; }
echo none
