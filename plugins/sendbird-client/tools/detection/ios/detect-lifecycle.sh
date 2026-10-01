#!/usr/bin/env bash
# Detect iOS app lifecycle entry: swiftui-app | scenedelegate | appdelegate | unknown
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
if file_contains "$dir" "*.swift" 'struct[[:space:]]+[A-Za-z0-9_]+[[:space:]]*:[[:space:]]*App\b'; then echo swiftui-app; exit 0; fi
if file_contains "$dir" "*.swift" 'class[[:space:]]+SceneDelegate'; then echo scenedelegate; exit 0; fi
if file_contains "$dir" "*.swift" '(UIApplicationDelegate|class[[:space:]]+AppDelegate)'; then echo appdelegate; exit 0; fi
echo unknown
