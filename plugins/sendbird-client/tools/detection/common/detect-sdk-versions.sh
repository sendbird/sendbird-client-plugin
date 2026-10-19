#!/usr/bin/env bash
# Detect the resolved Sendbird SDK version of each product in a project.
# Prints one "<product> <x.y.z>" line per product with an exact version, ordered
# chat, uikit, calls, desk, live, ai-agent. Nothing is printed for a product whose version
# is unknown (a dynamic Gradle version such as 3.+, or no lockfile and no exact range).
#
# detect-existing-integration.sh reports one version for the whole project; this keeps the
# products apart, because UIKit 3.x runs on Chat 4.x and "the" version is ambiguous.
# core/commands/search.sh uses the majors to keep docs for another major version out of
# its results. Read-only.
#
# Sources, in this order (the first exact version found for a product wins):
#   Package.resolved   pin identity containing uikit, calls, desk, live, or chat (the legacy v3
#                      mirror named in knowledge/curated/ios/setup.md is chat too); a swiftui pin
#                      has its own version line and is not reported
#   Podfile.lock       "- <pod> (x.y.z)" for pods starting with Send[Bb]ird: UIKit, Calls, Desk,
#                      Live by name; the Chat pod and the legacy v3 pod (knowledge/curated/ios/setup.md) -> chat
#   JS lockfiles       package-lock.json, yarn.lock, pnpm-lock.yaml, then package.json ranges
#                      (^4.9.0 -> 4.9.0); package names as in detect-products.sh, plus the npm
#                      package `sendbird`, the legacy v3 JavaScript SDK (npmjs.com/package/sendbird)
#   Gradle files       com.sendbird.sdk artifacts from gradle_sendbird_deps, plus the legacy v3
#                      artifact sendbird-android-sdk (repo.sendbird.com/public/maven); uikit-compose
#                      has its own version line and is not reported as uikit
set -euo pipefail
dir="${1:?usage: detect-sdk-versions.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"

js_product() { # npm package name -> product, or nothing
  case "$1" in
    @sendbird/chat|sendbird) echo chat ;;
    @sendbird/uikit-react|@sendbird/uikit-react-native) echo uikit ;;
    sendbird-calls|@sendbird/calls-react-native) echo calls ;;
    sendbird-desk) echo desk ;;
    @sendbird/live) echo live ;;
    @sendbird/ai-agent-messenger-react|@sendbird/ai-agent-messenger-react-native) echo ai-agent ;;
  esac
}

js_versions() {
  local pkg v p
  if [ -f "$dir/package-lock.json" ]; then
    jq -r '(.packages // {}) | to_entries[]
           | select(.key | test("^node_modules/(@sendbird/[^/]+|sendbird|sendbird-calls|sendbird-desk)$"))
           | [(.key | sub("^node_modules/"; "")), (.value.version // "")] | @tsv' "$dir/package-lock.json" 2>/dev/null \
      | while IFS="$(printf '\t')" read -r pkg v; do
          p="$(js_product "$pkg")"
          if [ -n "$p" ] && [ -n "$v" ]; then echo "$p $v"; fi
        done || true
  fi
  if [ -f "$dir/yarn.lock" ]; then
    # v1 entry header "@scope/name@^4.9.0": then `version "4.9.2"`; berry "@scope/name@npm:^4.9.0": then `version: 4.9.2`
    awk '
      /^[^[:space:]#]/ {
        h = $0; sub(/,.*/, "", h); gsub(/"/, "", h); sub(/:[[:space:]]*$/, "", h)
        if (substr(h, 1, 1) == "@") { i = index(substr(h, 2), "@"); pkg = (i ? substr(h, 1, i) : h) }
        else { i = index(h, "@"); pkg = (i ? substr(h, 1, i - 1) : h) }
        next
      }
      pkg != "" && /^[[:space:]]+version:?[[:space:]]/ {
        v = $0; sub(/^[[:space:]]+version:?[[:space:]]+/, "", v); gsub(/"/, "", v)
        if (v ~ /^[0-9]+\.[0-9]+\.[0-9]+/) print pkg, v
        pkg = ""
      }' "$dir/yarn.lock" 2>/dev/null \
      | while read -r pkg v; do
          p="$(js_product "$pkg")"
          if [ -n "$p" ]; then echo "$p $v"; fi
        done || true
  fi
  if [ -f "$dir/pnpm-lock.yaml" ]; then
    grep -oE "(@sendbird/[A-Za-z0-9._-]+|sendbird(-calls|-desk)?)[@/][0-9]+\.[0-9]+\.[0-9]+" "$dir/pnpm-lock.yaml" 2>/dev/null \
      | sed -E 's#^(.+)[@/]([0-9]+\.[0-9]+\.[0-9]+)$#\1 \2#' \
      | while read -r pkg v; do
          p="$(js_product "$pkg")"
          if [ -n "$p" ]; then echo "$p $v"; fi
        done || true
  fi
  if [ -f "$dir/package.json" ]; then
    jq -r '((.dependencies // {}) + (.devDependencies // {})) | to_entries[] | [.key, (.value | tostring)] | @tsv' \
      "$dir/package.json" 2>/dev/null \
      | while IFS="$(printf '\t')" read -r pkg v; do
          p="$(js_product "$pkg")"
          [ -n "$p" ] || continue
          v="$(printf '%s' "$v" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
          if [ -n "$v" ]; then echo "$p $v"; fi
        done || true
  fi
}

# "<product> <version>" candidates in priority order; the first per product is kept below.
candidates() {
  local res lock
  res="$(find "$dir" -name Package.resolved -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
  if [ -n "$res" ]; then
    jq -r '(.pins // .object.pins // [])[]
           | [((.identity // .package // "") | ascii_downcase), (.state.version // "")] | @tsv' "$res" 2>/dev/null \
      | awk -F'\t' 'index($1, "sendbird") {
          id = $1; p = ""
          if (index(id, "swiftui")) p = ""
          else if (index(id, "uikit")) p = "uikit"
          else if (index(id, "calls")) p = "calls"
          else if (index(id, "desk")) p = "desk"
          else if (index(id, "live")) p = "live"
          else if (index(id, "chat")) p = "chat"
          if (p != "" && $2 != "") print p, $2
        }' || true
  fi
  lock="$(find "$dir" -name Podfile.lock -not -path '*/.git/*' 2>/dev/null | head -1)"
  if [ -n "$lock" ]; then
    grep -oE '^  - Send[Bb]ird[A-Za-z]* \([0-9]+\.[0-9]+\.[0-9]+\)' "$lock" 2>/dev/null \
      | awk '{ n = $2; v = $3; gsub(/[()]/, "", v); p = ""
               if (n ~ /UIKit/) p = "uikit"; else if (n ~ /Calls/) p = "calls"
               else if (n ~ /Desk/) p = "desk"; else if (n ~ /Live/) p = "live"
               else if (n ~ /Chat/ || n ~ /^Send[Bb]ird[S][D][K]$/) p = "chat"
               if (p != "") print p, v }' || true
  fi
  js_versions
  gradle_sendbird_deps "$dir" | awk '$2 != "unknown" {
      a = $1; p = ""
      if (a == "sendbird-chat" || a == "sendbird-android-sdk") p = "chat"
      else if (a == "uikit") p = "uikit"
      else if (a == "sendbird-calls") p = "calls"
      else if (a == "sendbird-desk-android-sdk") p = "desk"
      else if (a == "sendbird-live") p = "live"
      else if (a == "ai-agent-messenger") p = "ai-agent"
      if (p != "") print p, $2 }' || true
}

candidates \
  | awk 'NF == 2 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+/ && !seen[$1]++ {
           v = $2; sub(/[^0-9.].*$/, "", v)
           o = ($1 == "chat") ? 1 : ($1 == "uikit") ? 2 : ($1 == "calls") ? 3 : ($1 == "desk") ? 4 : ($1 == "live") ? 5 : 6
           print o "\t" $1 " " v }' \
  | sort -n | cut -f2-
