#!/usr/bin/env bash
# Detect JS package manager: pnpm | yarn | npm | unknown
set -euo pipefail
dir="${1:?usage}"
[ -f "$dir/pnpm-lock.yaml" ] && { echo pnpm; exit 0; }
[ -f "$dir/yarn.lock" ] && { echo yarn; exit 0; }
[ -f "$dir/package-lock.json" ] && { echo npm; exit 0; }
[ -f "$dir/package.json" ] && { echo npm; exit 0; }
echo unknown
