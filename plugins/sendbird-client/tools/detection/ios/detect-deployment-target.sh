#!/usr/bin/env bash
# Detect iOS minimum deployment target, e.g. "15.0".
set -euo pipefail
dir="${1:?usage}"
pkg="$(find "$dir" -name Package.swift -not -path '*/.git/*' 2>/dev/null | head -1)"
if [ -n "$pkg" ]; then
  v="$(grep -oE '\.iOS\(\.v[0-9]+(_[0-9]+)?\)' "$pkg" | head -1 | grep -oE '[0-9]+(_[0-9]+)?' | tr '_' '.' || true)"
  [ -n "$v" ] && { case "$v" in *.*) echo "$v";; *) echo "$v.0";; esac; exit 0; }
  v="$(grep -oE '\.iOS\("[0-9]+\.[0-9]+"\)' "$pkg" | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)"
  [ -n "$v" ] && { echo "$v"; exit 0; }
fi
pod="$(find "$dir" -name Podfile -not -path '*/.git/*' 2>/dev/null | head -1)"
if [ -n "$pod" ]; then
  v="$(grep -oE "platform[[:space:]]*:ios,[[:space:]]*'[0-9]+\.[0-9]+'" "$pod" | grep -oE "[0-9]+\.[0-9]+" | head -1 || true)"
  [ -n "$v" ] && { echo "$v"; exit 0; }
fi
v="$(find "$dir" -name '*.xcconfig' -not -path '*/.git/*' -exec grep -hoE 'IPHONEOS_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*[0-9]+\.[0-9]+' {} + 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
[ -n "$v" ] && { echo "$v"; exit 0; }
echo unknown
