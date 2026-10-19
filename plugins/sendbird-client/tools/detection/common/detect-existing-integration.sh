#!/usr/bin/env bash
# Detect an existing Sendbird integration + resolved version.
# Prints: present=<true|false> version=<x.y.z|unknown>
# Looks at, in order: SwiftPM Package.resolved, Podfile.lock, package-lock.json, yarn.lock
# (v1 and berry), pnpm-lock.yaml, then Gradle build files and the version catalog.
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
ver="unknown"; present="false"
res="$(find "$dir" -name Package.resolved -not -path '*/.git/*' 2>/dev/null | head -1)"
if [ -n "$res" ]; then
  v="$(jq -r '[.pins[]? | select(.identity | test("sendbird")) | .state.version] | map(select(.!=null)) | .[0] // empty' "$res" 2>/dev/null)"
  [ -n "$v" ] && { present="true"; ver="$v"; }
fi
if [ "$present" = "false" ]; then
  lock="$(find "$dir" -name Podfile.lock -not -path '*/.git/*' 2>/dev/null | head -1)"
  if [ -n "$lock" ]; then
    v="$(grep -oE '(Sendbird[A-Za-z]+|SendBird[A-Za-z]+) \([0-9]+\.[0-9]+\.[0-9]+\)' "$lock" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -n "$v" ] && { present="true"; ver="$v"; }
  fi
fi
# JS lockfiles: the scoped @sendbird/* packages, and the older unscoped Chat v3 package
# "sendbird" and React UIKit v2 package "sendbird-uikit" (tools/detection/common/
# detect-legacy-majors.sh cites them).
if [ "$present" = "false" ] && [ -f "$dir/package-lock.json" ]; then
  v="$(jq -r '[(.packages // {}) | to_entries[] | select(.key | test("@sendbird/|(^|/)node_modules/sendbird(-uikit)?$")) | .value.version] | map(select(.!=null)) | .[0] // empty' "$dir/package-lock.json" 2>/dev/null)"
  [ -n "$v" ] && { present="true"; ver="$v"; }
fi
# yarn.lock: an entry header names the package ("@sendbird/chat@^4.9.0": in v1,
# "@sendbird/chat@npm:^4.9.0": in berry) and its indented block has the resolved version
# (`version "4.9.2"` in v1, `version: 4.9.2` in berry). The unscoped headers read
# sendbird@^3.1.0: (v1) and "sendbird@npm:^3.1.0": (berry).
if [ "$present" = "false" ] && [ -f "$dir/yarn.lock" ]; then
  v="$(awk '
    /^[^[:space:]#]/ { in_pkg = (index($0, "@sendbird/") > 0 || $0 ~ /^"?sendbird(-uikit)?@/); next }
    in_pkg && /^[[:space:]]+version:?[[:space:]]/ {
      v = $0; sub(/^[[:space:]]+version:?[[:space:]]+/, "", v); gsub(/"/, "", v)
      if (v ~ /^[0-9]+\.[0-9]+\.[0-9]+/) { print v; exit }
    }' "$dir/yarn.lock" 2>/dev/null || true)"
  [ -n "$v" ] && { present="true"; ver="$v"; }
fi
# pnpm-lock.yaml: package keys carry the resolved version: /@sendbird/chat@4.9.2: (v6),
# /@sendbird/chat/4.9.2: (v5), '@sendbird/chat@4.9.2': (v9), with an optional peer suffix;
# the unscoped packages the same way (/sendbird@3.1.33:, /sendbird/3.1.33:, sendbird@3.1.33:).
if [ "$present" = "false" ] && [ -f "$dir/pnpm-lock.yaml" ]; then
  v="$(grep -oE "(@sendbird/[A-Za-z0-9._-]+|(^|[[:space:]/'\"])sendbird(-uikit)?)[@/][0-9]+\.[0-9]+\.[0-9]+" "$dir/pnpm-lock.yaml" 2>/dev/null \
    | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$' || true)"
  [ -n "$v" ] && { present="true"; ver="$v"; }
fi
# Gradle: a declared com.sendbird.sdk dependency means the integration is present, even when
# its version is dynamic (3.+) or a variable; the version is reported only when it is exact.
# Prefer the Chat SDK's version, then the first exact one.
if [ "$present" = "false" ]; then
  deps="$(gradle_sendbird_deps "$dir")"
  if [ -n "$deps" ]; then
    present="true"
    v="$(printf '%s\n' "$deps" | awk '$1 == "sendbird-chat" && $2 != "unknown" { print $2; exit }')"
    [ -n "$v" ] || v="$(printf '%s\n' "$deps" | awk '$2 != "unknown" { print $2; exit }')"
    [ -n "$v" ] && ver="$v"
  fi
fi
echo "present=$present version=$ver"
