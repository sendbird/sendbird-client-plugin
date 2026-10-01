#!/usr/bin/env bash
# Render public API surface from `javap -p` text output (customer-installed). public only.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
f="${1:?usage}"; title="${2:?title}"; source_path="${3:-$f}"
[ -f "$f" ] || { render_empty "$title" "no javap output at $f"; exit 0; }
render_header "$title" "$source_path"
grep -E '^[[:space:]]*public[[:space:]].*(class|interface|enum|void|[A-Za-z0-9_.<>]+)[[:space:]]' "$f" \
  | grep -vE '^\s*(private|protected)' \
  | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\{[[:space:]]*$//; s/;[[:space:]]*$//; s/[[:space:]]*$//' \
  | sed -E 's/^/- `/; s/$/`/' \
  | sort -u
