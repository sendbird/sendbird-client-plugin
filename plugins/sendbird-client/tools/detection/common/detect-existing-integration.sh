#!/usr/bin/env bash
# Detect an existing Sendbird integration + resolved version.
# Prints: present=<true|false> version=<x.y.z|unknown>
set -euo pipefail
dir="${1:?usage}"
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
if [ "$present" = "false" ] && [ -f "$dir/package-lock.json" ]; then
  v="$(jq -r '[(.packages // {}) | to_entries[] | select(.key | test("@sendbird/")) | .value.version] | map(select(.!=null)) | .[0] // empty' "$dir/package-lock.json" 2>/dev/null)"
  [ -n "$v" ] && { present="true"; ver="$v"; }
fi
echo "present=$present version=$ver"
