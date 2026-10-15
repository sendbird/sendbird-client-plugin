#!/usr/bin/env bash
# Shared helpers for detectors. Source this file.

# has_glob <dir> <glob...> : 0 if any file matching any glob exists (recursive)
has_glob() {
  local dir="$1"; shift
  local g
  for g in "$@"; do
    if find "$dir" -type f -name "$g" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

# file_contains <dir> <ext-glob> <regex> : 0 if any matching file contains the regex
file_contains() {
  local dir="$1" glob="$2" re="$3"
  find "$dir" -type f -name "$glob" -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null \
    | xargs -0 grep -lE "$re" 2>/dev/null | grep -q .
}

# pkgjson_has_dep <dir> <dep-name> : 0 if package.json lists the dep in deps/devDeps
pkgjson_has_dep() {
  local dir="$1" dep="$2" pj="$1/package.json"
  [ -f "$pj" ] || return 1
  jq -e --arg d "$dep" '((.dependencies // {}) + (.devDependencies // {})) | has($d)' "$pj" >/dev/null 2>&1
}

# gradle_files <dir> : Gradle build scripts and version catalogs (gradle/libs.versions.toml)
gradle_files() {
  find "$1" -type f \( -name '*.gradle' -o -name '*.gradle.kts' -o -name '*.versions.toml' \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/build/*' 2>/dev/null
}

# gradle_sendbird_deps <dir> : every com.sendbird.sdk dependency in the Gradle files, one per line
# as "<artifact> <version>". Handles "com.sendbird.sdk:<artifact>[:<version>]" and
# group = "com.sendbird.sdk", name = "<artifact>". The version is the literal x.y.z, or in a
# version catalog the [versions] entry that version.ref names; anything else (3.+, a Gradle
# variable) is "unknown".
gradle_sendbird_deps() {
  gradle_files "$1" | while IFS= read -r f; do
    awk '
      /^[[:space:]]*\[/ { sect = $0; gsub(/[][[:space:]]/, "", sect) }
      sect == "versions" && /=/ {
        k = $0; sub(/[[:space:]]*=.*/, "", k); gsub(/[[:space:]"]/, "", k)
        v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); gsub(/[[:space:]"]/, "", v); vers[k] = v
      }
      { lines[++n] = $0 }
      END {
        for (i = 1; i <= n; i++) {
          l = lines[i]; a = ""; v = ""
          if (match(l, /com\.sendbird\.sdk:[A-Za-z0-9._-]+(:[A-Za-z0-9.+_-]+)?/)) {
            c = substr(l, RSTART + 17, RLENGTH - 17); p = index(c, ":")
            if (p) { a = substr(c, 1, p - 1); v = substr(c, p + 1) } else a = c
          } else if (l ~ /group[[:space:]]*=[[:space:]]*"com\.sendbird\.sdk"/ && match(l, /name[[:space:]]*=[[:space:]]*"[^"]+"/)) {
            a = substr(l, RSTART, RLENGTH); sub(/^name[[:space:]]*=[[:space:]]*"/, "", a); sub(/"$/, "", a)
          } else continue
          if (v == "" && match(l, /version\.ref[[:space:]]*=[[:space:]]*"[^"]+"/)) {
            r = substr(l, RSTART, RLENGTH); sub(/^version\.ref[[:space:]]*=[[:space:]]*"/, "", r); sub(/"$/, "", r); v = vers[r]
          } else if (v == "" && match(l, /version[[:space:]]*=[[:space:]]*"[^"]+"/)) {
            v = substr(l, RSTART, RLENGTH); sub(/^version[[:space:]]*=[[:space:]]*"/, "", v); sub(/"$/, "", v)
          }
          if (v !~ /^[0-9]+\.[0-9]+\.[0-9]+$/) v = "unknown"
          print a, v
        }
      }' "$f"
  done
}

# gradle_sendbird_artifacts <dir> : the artifact names gradle_sendbird_deps finds
gradle_sendbird_artifacts() { gradle_sendbird_deps "$1" | cut -d' ' -f1 | sort -u; }

# json_escape <string> : escape for embedding in JSON value
json_escape() { printf '%s' "$1" | jq -Rs .; }
