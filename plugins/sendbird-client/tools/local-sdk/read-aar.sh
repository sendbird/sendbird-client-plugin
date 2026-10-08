#!/usr/bin/env bash
# Extract the public class and member surface from one installed Android AAR.
set -euo pipefail
aar="${1:?usage: read-aar.sh <file.aar> <title>}"; title="${2:?title}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
[ -f "$aar" ] || { render_empty "$title" "AAR not found: $aar"; exit 0; }
eval "$(bash "$HERE/android-toolchain.sh")"
if ! command -v javap >/dev/null || ! command -v jar >/dev/null || ! command -v unzip >/dev/null; then
  render_empty "$title" "javap, jar, and unzip are required to inspect an AAR"
  exit 0
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
unzip -p "$aar" classes.jar > "$tmp/classes.jar"
# Nested classes stay (Params$Builder, SendbirdChat$Options, X$Companion); drop only R,
# BuildConfig, anonymous classes ($1), when-mapping tables, synthetic lambdas ($$), and
# internal/impl packages.
classes="$(jar tf "$tmp/classes.jar" | grep '\.class$' \
  | grep -vE '(^|/)(R|R\$.*|BuildConfig)\.class$|\$[0-9]+(\$|\.class$)|\$WhenMappings\.class$|\$\$|/(internal|impl)/' \
  | sed 's#/#.#g; s#\.class$##' || true)"
[ -n "$classes" ] || { render_empty "$title" "no public class candidates in $aar"; exit 0; }
: > "$tmp/javap.txt"
while IFS= read -r class_name; do
  javap -public -classpath "$tmp/classes.jar" "$class_name" >> "$tmp/javap.txt" 2>/dev/null || true
done <<< "$classes"
bash "$HERE/read-javap.sh" "$tmp/javap.txt" "$title" "$aar"
