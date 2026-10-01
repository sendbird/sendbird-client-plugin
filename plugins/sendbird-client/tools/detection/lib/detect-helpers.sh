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

# json_escape <string> : escape for embedding in JSON value
json_escape() { printf '%s' "$1" | jq -Rs .; }
