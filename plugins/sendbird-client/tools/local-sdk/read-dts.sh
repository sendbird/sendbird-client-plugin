#!/usr/bin/env bash
# Render the public API surface of a customer-installed npm package (or one .d.ts file).
# Usage: read-dts.sh <package-dir | file.d.ts> <title> [project-dir]
#
# Primary: lib/js-dts.cjs reads the package with the TypeScript compiler (follows
# re-exports, inheritance and namespaces; lists class members). It needs node and the
# `typescript` package, resolved from the project first.
# Fallback (no node or no typescript): names of exported declarations only, following
# `export * from` through relative files, for the main entry and every `exports`
# subpath. Members and signatures are not listed in the fallback.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
target="${1:?usage: read-dts.sh <package-dir | file.d.ts> <title> [project-dir]}"; title="${2:?title}"; project="${3:-}"
[ -e "$target" ] || { render_empty "$title" "no .d.ts or package at $target"; exit 0; }

reason="node is not installed"
if command -v node >/dev/null 2>&1; then
  err="$(mktemp)"; trap 'rm -f "$err"' EXIT
  if body="$(node "$HERE/lib/js-dts.cjs" "$target" "$title" "$project" 2>"$err")"; then
    render_header "$title" "$target"
    printf '%s\n' "$body"
    exit 0
  fi
  reason="$(tail -1 "$err")"
fi

# --- fallback: exported names only ------------------------------------------------
# Entries: "<import path>\t<file>" for the main entry and every subpath in "exports".
entries=""
if [ -d "$target" ]; then
  pj="$target/package.json"
  name="$(jq -r '.name // empty' "$pj" 2>/dev/null || true)"; name="${name:-$title}"
  entries="$(jq -r --arg n "$name" '
    def types: if type == "string" then (if endswith(".d.ts") then . else empty end)
               elif type == "object" then (.types // ([.import, .require, .default, .node] | map(select(. != null) | types) | first)) // empty
               else empty end;
    (.exports // {}) as $e
    | if ($e | type) == "object" then
        $e | to_entries[]
        | select((.key | test("\\*")) | not) | select(.key != "./package.json")
        | select((.key | test("/(tests?|__tests__|internal|dev-only|experimental|\\.private)(/|$)"; "i")) | not)
        | (.value | types) as $t | select($t != null)
        | "\(if .key == "." then $n else $n + "/" + (.key | ltrimstr("./")) end)\t\($t)"
      else empty end' "$pj" 2>/dev/null || true)"
  if ! printf '%s\n' "$entries" | grep -q "^${name}"$'\t'; then
    rel="$(jq -r '.types // .typings // empty' "$pj" 2>/dev/null || true)"
    [ -n "$rel" ] && [ -f "$target/$rel" ] || rel="index.d.ts"
    [ -f "$target/$rel" ] && entries="$name"$'\t'"$rel"$'\n'"$entries"
  fi
  # Keep only entries whose file exists, as absolute paths.
  entries="$(printf '%s\n' "$entries" | while IFS=$'\t' read -r ip rel; do
    if [ -n "$ip" ] && [ -f "$target/$rel" ]; then
      printf '%s\t%s\n' "$ip" "$(cd "$(dirname "$target/$rel")" && pwd)/$(basename "$rel")"
    fi
  done)"
  [ -n "$entries" ] || { render_empty "$title" "no type declarations in $target"; exit 0; }
else
  entries="$title"$'\t'"$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
fi

# Resolve `from './x'` relative to a file: x.d.ts, x/index.d.ts, x.js -> x.d.ts.
resolve_rel() {
  local base="$1" spec="$2" p
  p="$(cd "$(dirname "$base")" && pwd)/$spec"
  for c in "$p" "${p%.js}.d.ts" "$p.d.ts" "$p/index.d.ts"; do
    case "$c" in *.d.ts) [ -f "$c" ] && { printf '%s\n' "$c"; return 0; } ;; esac
  done
  return 1
}

# One pass per file: `STAR <spec>` for `export * from`, `NAME <name>` for every exported
# declaration and every name in an `export { ... }` list (which may span lines).
scan() {
  awk '
    function names(list,   n, i, parts, x) {
      n = split(list, parts, ",")
      for (i = 1; i <= n; i++) {
        x = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", x); sub(/^type[ \t]+/, "", x)
        if (x ~ /[ \t]as[ \t]/) sub(/.*[ \t]as[ \t]+/, "", x)
        if (x ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/ && x != "default") print "NAME " x
      }
    }
    inlist { buf = buf " " $0; if (buf ~ /\}/) { sub(/\}.*/, "", buf); names(buf); inlist = 0 } ; next }
    /^[ \t]*export[ \t]+\*[ \t]+as[ \t]+[A-Za-z_$]/ { x = $0; sub(/^[ \t]*export[ \t]+\*[ \t]+as[ \t]+/, "", x); sub(/[^A-Za-z0-9_$].*/, "", x); print "NAME " x; next }
    /^[ \t]*export[ \t]+\*[ \t]+from[ \t]/ { x = $0; sub(/^[^\x27"]*[\x27"]/, "", x); sub(/[\x27"].*/, "", x); print "STAR " x; next }
    /^[ \t]*export[ \t]+(type[ \t]+)?\{/ {
      buf = $0; sub(/^[^{]*\{/, "", buf)
      if (buf ~ /\}/) { sub(/\}.*/, "", buf); names(buf) } else inlist = 1
      next
    }
    /^[ \t]*export[ \t]+(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?(class|function|interface|type|enum|const|let|var|namespace)[ \t]+[A-Za-z_$]/ {
      x = $0; sub(/^[ \t]*export[ \t]+(default[ \t]+)?(declare[ \t]+)?(abstract[ \t]+)?/, "", x)
      sub(/[ \t]*[{=(<:;].*$/, "", x); sub(/[ \t]+(extends|implements)[ \t].*$/, "", x)
      if (x !~ /[ \t]_/) print "NAME " x
    }
  ' "$1"
}

# Names exported from one entry, following relative `export * from` chains.
names_of() {
  local queue=("$1") seen=" " f out spec next
  while [ "${#queue[@]}" -gt 0 ]; do
    f="${queue[0]}"; queue=("${queue[@]:1}")
    case "$seen" in *" $f "*) continue ;; esac
    seen="$seen$f "
    out="$(scan "$f")"
    printf '%s\n' "$out" | sed -n 's/^NAME //p'
    while IFS= read -r spec; do
      case "$spec" in .*) if next="$(resolve_rel "$f" "$spec")"; then queue+=("$next"); fi ;; esac
    done < <(printf '%s\n' "$out" | sed -n 's/^STAR //p')
  done
}

count="$(printf '%s\n' "$entries" | sed '/^$/d' | wc -l | tr -d ' ')"
render_header "$title" "$target"
echo "_TypeScript compiler unavailable (${reason}). Exported names only, per import path (${count}); class members, inherited members and signatures are not listed. Install \`typescript\` in the project for the full surface._"
while IFS=$'\t' read -r ip file; do
  [ -n "$ip" ] || continue
  list="$(names_of "$file" | sed '/^$/d' | sort -u)"
  [ -n "$list" ] || continue
  echo
  echo "## \`$ip\`"
  printf '%s\n' "$list" | sed -E 's/^/- `/; s/$/`/'
done <<< "$entries"
