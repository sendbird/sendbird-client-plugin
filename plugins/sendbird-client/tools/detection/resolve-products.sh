#!/usr/bin/env bash
# Resolve the active product scope for one project.
# Usage: resolve-products.sh <project-dir> [--check <product>]
# Order: SENDBIRD_PRODUCTS > .sendbird-client/profile.json enabledProducts > every supported product.
# A product in config .productScope.notYetSupported is never in scope: it is left out of the
# default, dropped (with a note on stderr) from SENDBIRD_PRODUCTS or the profile, and
# `--check <product>` fails with "product not supported yet" instead of "out of configured scope".
# A product this plugin does not ship (not in config .products, for example AI Agent in an edition
# without it) fails `--check` with "product not covered by this plugin": widening SENDBIRD_PRODUCTS or
# the profile cannot add it, so the answer must not suggest that.
# A product the plugin covers that the project's host cannot run (config .productScope.unsupportedHosts, for
# example Live on React Native) fails `--check` with "product not available on this host" and the reason.
# The host is the profile's, else the side-effect-free detector's (core/commands/detect.sh).
set -euo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
dir="${1:?usage: resolve-products.sh <project-dir> [--check <product>]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
config="$ROOT/config/plugin-config.json"
supported="$(jq -r '.products[]' "$config" | sort)"
not_yet="$(jq -r '.productScope.notYetSupported[]? // empty' "$config" | sort)"
is_not_yet() { [ -n "$not_yet" ] && printf '%s\n' "$not_yet" | grep -Fxq "$1"; }
not_yet_note() { # $1 = product, $2 = optional "left out of ..." clause
  echo "product not supported yet: $1${2:+ ($2)} — this plugin release does not support it yet; tell the customer it is not supported yet and do not write code for it" >&2
}

if [ "${2:-}" = "--check" ]; then
  requested="${3:?usage: resolve-products.sh <project-dir> --check <product>}"
  if is_not_yet "$requested"; then not_yet_note "$requested"; exit 1; fi
  if ! printf '%s\n' "$supported" | grep -Fxq "$requested"; then
    echo "product not covered by this plugin: $requested — this plugin covers $(printf '%s\n' "$supported" | paste -sd, - | sed 's/,/, /g'); tell the customer this plugin does not cover $requested, write no code for it, and do not suggest SENDBIRD_PRODUCTS or enabledProducts (they cannot add it)" >&2
    exit 1
  fi
  why_host() { # $1 = host : the reason the requested product cannot run on it, or nothing
    jq -r --arg p "$requested" --arg h "$1" '.productScope.unsupportedHosts[$p][$h] // empty' "$config"
  }
  if [ -n "$(jq -r --arg p "$requested" '.productScope.unsupportedHosts[$p] // empty | keys[]' "$config" 2>/dev/null)" ]; then
    host="$(jq -r '.host // empty' "$dir/.sendbird-client/profile.json" 2>/dev/null || true)"
    [ -n "$host" ] || host="$(bash "$ROOT/core/commands/detect.sh" "$dir" 2>/dev/null | jq -r '.host // empty' 2>/dev/null || true)"
    reason=""
    [ -z "$host" ] || reason="$(why_host "$host")"
    if [ -n "$reason" ]; then
      echo "product not available on this host: $requested on $host — $reason; tell the customer that, change no file and write no code for it, and do not suggest SENDBIRD_PRODUCTS or enabledProducts (they cannot change it)" >&2
      exit 1
    fi
  fi
fi

selected=""; source_name=""
if [ -n "${SENDBIRD_PRODUCTS:-}" ]; then
  selected="$(printf '%s' "$SENDBIRD_PRODUCTS" | tr ',' '\n' | tr -d ' ' | sed '/^$/d' | sort -u)"
  source_name="SENDBIRD_PRODUCTS"
else
  profile="$dir/.sendbird-client/profile.json"
  [ -f "$profile" ] && selected="$(jq -r '.enabledProducts[]? // empty' "$profile" 2>/dev/null | sed '/^$/d' | sort -u || true)"
  [ -n "$selected" ] && source_name="$profile enabledProducts"
fi

if [ -n "$selected" ]; then
  kept=""
  while IFS= read -r product; do
    [ -n "$product" ] || continue
    if is_not_yet "$product"; then
      not_yet_note "$product" "left out of the scope from $source_name"
      continue
    fi
    kept="${kept:+$kept$'\n'}$product"
  done <<< "$selected"
  if [ -z "$kept" ]; then
    echo "no supported product left in the scope from $source_name" >&2
    exit 1
  fi
  selected="$kept"
else
  selected=""
  while IFS= read -r product; do
    is_not_yet "$product" || selected="${selected:+$selected$'\n'}$product"
  done <<< "$supported"
fi

while IFS= read -r product; do
  [ -n "$product" ] || continue
  printf '%s\n' "$supported" | grep -Fxq "$product" || {
    echo "unsupported product in scope: $product" >&2
    exit 1
  }
done <<< "$selected"

if [ "${2:-}" = "--check" ]; then
  printf '%s\n' "$selected" | grep -Fxq "$requested" && exit 0
  echo "product out of configured scope: $requested" >&2
  exit 1
fi

printf '%s\n' "$selected" | paste -sd, -
