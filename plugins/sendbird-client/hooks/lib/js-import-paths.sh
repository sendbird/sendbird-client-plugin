#!/usr/bin/env bash
# Import-path check for JS/TS writes (source-claim-guard.sh). Source this file.
#
# A Sendbird JS package exports most of its API from subpaths, not from the package root:
#   import type { SendbirdGroupChat } from '@sendbird/chat';              <- TS2724, no such export
#   import type { SendbirdGroupChat } from '@sendbird/chat/groupChannel'; <- what the SDK exports
# tools/local-sdk/read-surface.sh caches the installed package's surface at
# <project>/.sendbird-client/cache/<product>/api-surface.md, and under every `## <kind> <Name>`
# heading it writes the paths that export that name:
#   Exported from: `@sendbird/chat/groupChannel`, `@sendbird/chat/aiAgent`
# A default export carries " (default export)" after its path (`@sendbird/chat (default export)`).

# surface_project_dir <file path> <cwd> : prints the nearest folder, from the file's folder up, that
# holds a .sendbird-client/cache folder, then the session cwd; fails when none does.
surface_project_dir() {
  local p="$1" cwd="$2" d
  case "$p" in /*) ;; *) p="${cwd:-$(pwd)}/$p" ;; esac
  d="$(dirname "$p")"
  while [ -n "$d" ]; do
    if [ -d "$d/.sendbird-client/cache" ]; then printf '%s' "$d"; return 0; fi
    [ "$d" = / ] && break
    d="$(dirname "$d")"
  done
  if [ -n "$cwd" ] && [ -d "$cwd/.sendbird-client/cache" ]; then printf '%s' "$cwd"; return 0; fi
  return 1
}

# surface_export_paths <name> <surface files...> : prints "<import path>\t<surface file>" for every
# path the surfaces list under a `## <kind> <name>` heading ("(default export)" kept on the path)
surface_export_paths() {
  local name="$1"; shift
  awk -v name="$name" '
    /^## / {
      insec = 0
      if ($0 == "## Import paths" || $0 ~ /^## Unresolved references/) next
      n = split($0, w, " "); if (w[n] == name) insec = 1
      next
    }
    insec && /^Exported from: / {
      line = $0
      while (match(line, /`[^`]+`/)) {
        print substr(line, RSTART + 1, RLENGTH - 2) "\t" FILENAME
        line = substr(line, RSTART + RLENGTH)
      }
      insec = 0
    }' "$@" 2>/dev/null
}

# js_import_path_problem <file path> <code> <cwd> : prints why a named import in <code> is wrong
# when <file path> is a JS/TS file, the project has a cached API surface, and that surface lists a
# name imported from '@sendbird/<pkg>[/<sub>]' only under other paths of the same package. Prints
# nothing otherwise: a name the surface does not list is left to the other checks, and default and
# namespace imports are not checked.
js_import_path_problem() {
  local file="$1" code="$2" cwd="$3" proj stmt module pkg item name rows named defaults hit cite re
  case "$file" in *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx|*.mjs|*.cjs) ;; *) return 0 ;; esac
  proj="$(surface_project_dir "$file" "$cwd")" || return 0
  local surfaces=()
  for item in "$proj"/.sendbird-client/cache/*/api-surface.md; do [ -f "$item" ] && surfaces+=("$item"); done
  [ "${#surfaces[@]}" -gt 0 ] || return 0
  # import { A, type B, C as D } from '...'; import type { ... } from '...'; import X, { ... } from '...'
  # (the quote may be escaped when the code sits inside a shell or script string)
  re='(import|export)[[:space:]]+(type[[:space:]]+)?([A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*,[[:space:]]*)?\{[^}]*\}[[:space:]]*from[[:space:]]*\\?['"'"'"]@sendbird/[^'"'"'"\\[:space:]]+'
  while IFS= read -r stmt; do
    [ -n "$stmt" ] || continue
    module="@sendbird/${stmt##*@sendbird/}"
    pkg="$(printf '%s' "$module" | cut -d/ -f1-2)"
    while IFS= read -r item; do
      name="$(printf '%s' "$item" | sed -E 's/^[[:space:]]*(type[[:space:]]+)?//; s/[[:space:]]+as[[:space:]].*$//; s/[[:space:]]+$//')"
      [[ "$name" =~ ^[A-Za-z_\$][A-Za-z0-9_\$]*$ ]] || continue
      [ "$name" = default ] && continue
      # only the paths of the imported package count
      rows="$(surface_export_paths "$name" "${surfaces[@]}" | awk -F'\t' -v pkg="$pkg" '
        { p = $1; sub(/ \(default export\)$/, "", p) }
        p == pkg || index(p, pkg "/") == 1')"
      [ -n "$rows" ] || continue
      named="$(printf '%s\n' "$rows" | cut -f1 | grep -v ' (default export)$' | awk '!seen[$0]++' || true)"
      grep -Fxq -- "$module" <<< "$named" && continue
      defaults="$(printf '%s\n' "$rows" | cut -f1 | grep ' (default export)$' | sed 's/ (default export)$//' | awk '!seen[$0]++' || true)"
      hit="$(printf '%s\n' "$rows" | head -n 1 | cut -f2)"
      cite="${hit#"$proj"/}"
      if [ -n "$named" ]; then
        printf '`%s` is not exported from `%s`; the installed SDK exports it from %s (%s). Import it from that path.' \
          "$name" "$module" "$(printf '%s\n' "$named" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')" "$cite"
      elif grep -Fxq -- "$module" <<< "$defaults"; then
        printf '`%s` is the default export of `%s`, not a named export (%s). Import it as `import %s from '"'"'%s'"'"'`.' \
          "$name" "$module" "$cite" "$name" "$module"
      else
        printf '`%s` is not exported from `%s`; the installed SDK exports it only as the default export of %s (%s).' \
          "$name" "$module" "$(printf '%s\n' "$defaults" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')" "$cite"
      fi
      return 0
    done < <(printf '%s\n' "$stmt" | sed -E 's/^[^{]*\{([^}]*)\}.*$/\1/' | tr ',' '\n')
  done < <(printf '%s' "$code" | tr '\n\r\t' '   ' | grep -Eo "$re" || true)
  return 0
}
