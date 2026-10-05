#!/usr/bin/env bash
# Detect Android minSdk, e.g. "24". Reads a literal from build.gradle(.kts), then a
# version catalog (gradle/libs.versions.toml, e.g. minSdk = "24"). Prints "unknown"
# otherwise (convention plugins, computed values): a no-match grep must not end the script.
set -euo pipefail
dir="${1:?usage}"
v="$(find "$dir" \( -name 'build.gradle' -o -name 'build.gradle.kts' \) -not -path '*/.git/*' \
    -exec grep -hoE 'minSdk(Version)?[[:space:]]*[=(]?[[:space:]]*[0-9]+' {} + 2>/dev/null \
  | grep -oE '[0-9]+' | head -1 || true)"
if [ -z "$v" ]; then
  v="$(find "$dir" -name 'libs.versions.toml' -not -path '*/.git/*' \
      -exec grep -hoE '^[[:space:]]*[A-Za-z-]*min-?[Ss]dk[A-Za-z-]*[[:space:]]*=[[:space:]]*"?[0-9]+' {} + 2>/dev/null \
    | grep -oE '[0-9]+$' | head -1 || true)"
fi
[ -n "$v" ] && { echo "$v"; exit 0; }
echo unknown
