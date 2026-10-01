#!/usr/bin/env bash
# Detect platform: ios | android | js | unknown
set -euo pipefail
dir="${1:?usage: detect-platform.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"

ios=0; android=0; js=0
has_glob "$dir" "Package.swift" "*.xcodeproj" "*.xcworkspace" "Podfile" "*.swift" && ios=1
has_glob "$dir" "build.gradle" "build.gradle.kts" "settings.gradle" "settings.gradle.kts" "*.kt" && android=1
[ -f "$dir/package.json" ] && js=1

sum=$((ios + android + js))
# A standard React Native project contains package.json plus native ios/ and
# android/ trees. Treat it as JS when the manifest declares react-native.
if [ "$js" -eq 1 ] && pkgjson_has_dep "$dir" "react-native"; then
  echo js
  exit 0
fi
if [ "$sum" -eq 1 ]; then
  [ "$ios" -eq 1 ] && echo ios && exit 0
  [ "$android" -eq 1 ] && echo android && exit 0
  [ "$js" -eq 1 ] && echo js && exit 0
fi
echo unknown
