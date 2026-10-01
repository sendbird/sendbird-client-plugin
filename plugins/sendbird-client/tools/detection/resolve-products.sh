#!/usr/bin/env bash
# Resolve the active product scope for one project.
# Usage: resolve-products.sh <project-dir> [--check <product>]
# Order: SENDBIRD_PRODUCTS > .sendbird-client/profile.json enabledProducts > every supported product.
set -euo pipefail
dir="${1:?usage: resolve-products.sh <project-dir> [--check <product>]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
config="$ROOT/config/plugin-config.json"
supported="$(jq -r '.products[]' "$config" | sort)"

selected=""
if [ -n "${SENDBIRD_PRODUCTS:-}" ]; then
  selected="$(printf '%s' "$SENDBIRD_PRODUCTS" | tr ',' '\n' | tr -d ' ' | sed '/^$/d' | sort -u)"
else
  profile="$dir/.sendbird-client/profile.json"
  [ -f "$profile" ] && selected="$(jq -r '.enabledProducts[]? // empty' "$profile" 2>/dev/null | sed '/^$/d' | sort -u || true)"
fi
[ -n "$selected" ] || selected="$supported"

while IFS= read -r product; do
  [ -n "$product" ] || continue
  printf '%s\n' "$supported" | grep -Fxq "$product" || {
    echo "unsupported product in scope: $product" >&2
    exit 1
  }
done <<< "$selected"

if [ "${2:-}" = "--check" ]; then
  requested="${3:?usage: resolve-products.sh <project-dir> --check <product>}"
  printf '%s\n' "$selected" | grep -Fxq "$requested" && exit 0
  echo "product out of configured scope: $requested" >&2
  exit 1
fi

printf '%s\n' "$selected" | paste -sd, -
