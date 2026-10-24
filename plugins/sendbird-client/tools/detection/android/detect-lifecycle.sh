#!/usr/bin/env bash
# Detect where an Android app initializes: application | application-missing
#   application          the app's AndroidManifest.xml names an Application class (<application
#                        android:name="...">), or, with no manifest found, a source file declares a
#                        subclass of Application: initialize once in its onCreate
#   application-missing  no Application class: add one, initialize in its onCreate, and register it in
#                        AndroidManifest.xml (knowledge/curated/android/setup.md "Init")
# Never unknown, so setup does not stop to ask about it on an Android project.
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
manifests="$(find "$dir" -type f -name AndroidManifest.xml -not -path '*/build/*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)"
if [ -n "$manifests" ]; then
  # the <application ...> start tag, which may span lines, and an android:name attribute in it
  while IFS= read -r m; do
    if tr '\n' ' ' < "$m" | grep -Eo '<application[[:space:]][^>]*>' | grep -Eq 'android:name[[:space:]]*=[[:space:]]*"[^"]+"'; then
      echo application; exit 0
    fi
  done <<< "$manifests"
  echo application-missing; exit 0
fi
if file_contains "$dir" "*.kt" 'class[[:space:]]+[A-Za-z0-9_]+[^{]*:[[:space:]]*(android\.app\.)?(MultiDex)?Application[[:space:]]*\(' \
  || file_contains "$dir" "*.java" 'class[[:space:]]+[A-Za-z0-9_]+[[:space:]]+extends[[:space:]]+(android\.app\.)?(MultiDex)?Application\b'; then
  echo application; exit 0
fi
echo application-missing
