#!/usr/bin/env bash
# Tier-2: how a JS project can read the Sendbird App ID at runtime.
# Prints next | expo | vite | cra | config. `config` means no env loader was found:
# put the App ID in a config module (App IDs are not secret) instead of asking the
# customer to install a bundler. Non-JS projects print n/a.
# Rules per value: knowledge/curated/js/setup.md "App ID".
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
[ -f "$dir/package.json" ] || { echo n/a; exit 0; }
pkgjson_has_dep "$dir" "next" && { echo next; exit 0; }
pkgjson_has_dep "$dir" "expo" && { echo expo; exit 0; }
pkgjson_has_dep "$dir" "vite" && { echo vite; exit 0; }
pkgjson_has_dep "$dir" "react-scripts" && { echo cra; exit 0; }
echo config
