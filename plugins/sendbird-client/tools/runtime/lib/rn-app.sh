#!/usr/bin/env bash
# What the runtime harness needs to know about a React Native project, read from its files.
#   rn-app.sh entry <project>   the entry a release build bundles: index.js (or .ts, .tsx, .jsx) at the root
#   rn-app.sh login <project>   the module that exports onLoginSucceeded(userId), relative to the project
# Prints nothing (exit 1) when there is none. node_modules, ios/, and android/ are never searched.
# The React Native docs' release builds bundle index.js by default (the iOS bundle script and the
# React Native Gradle plugin); a project with another entry sets it in its build files and is not
# handled here.
set -uo pipefail
dir="${2:-}"; [ "$dir" = / ] || dir="${dir%/}"
[ -d "$dir" ] || { echo "usage: rn-app.sh entry|login <project>" >&2; exit 64; }
case "${1:-}" in
  entry)
    for f in index.js index.ts index.tsx index.jsx; do [ -f "$dir/$f" ] && { echo "$f"; exit 0; }; done
    exit 1 ;;
  login)
    f="$(grep -rlE --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
      --exclude-dir=node_modules --exclude-dir=ios --exclude-dir=android --exclude-dir=.git \
      'export[[:space:]]+(async[[:space:]]+)?function[[:space:]]+onLoginSucceeded\b|export[[:space:]]+const[[:space:]]+onLoginSucceeded\b' "$dir" 2>/dev/null | sort | head -1)"
    [ -n "$f" ] || exit 1
    echo "${f#"$dir"/}" ;;
  *) echo "usage: rn-app.sh entry|login <project>" >&2; exit 64 ;;
esac
