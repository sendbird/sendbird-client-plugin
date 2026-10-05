#!/usr/bin/env bash
# Render public API surface from `javap -p` text output (customer-installed). public only.
# Members whose own name contains `$` are compiler-generated (Kotlin internal
# `foo$module_release`, `foo$default`, `access$foo`, `$annotations`, `$p`/`$cp`
# accessors) and cannot be called from Kotlin source, so they are dropped. Nested-class
# constructors keep their dotted name (com.x.Outer$Inner(...)) and stay.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
f="${1:?usage}"; title="${2:?title}"; source_path="${3:-$f}"
[ -f "$f" ] || { render_empty "$title" "no javap output at $f"; exit 0; }
render_header "$title" "$source_path"
# every `public` declaration line, including no-arg and one-arg constructors (no inner space)
grep -E '^[[:space:]]*public[[:space:]]' "$f" \
  | grep -vE '^\s*(private|protected)' \
  | grep -vE '[[:space:]][A-Za-z_][A-Za-z0-9_]*\$[A-Za-z0-9_$]*\(|[[:space:]]\$[A-Za-z0-9_]+;?[[:space:]]*$' \
  | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\{[[:space:]]*$//; s/;[[:space:]]*$//; s/[[:space:]]*$//' \
  | sed -E 's/^/- `/; s/$/`/' \
  | sort -u
