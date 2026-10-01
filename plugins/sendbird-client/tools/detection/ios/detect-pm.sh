#!/usr/bin/env bash
# Detect iOS package manager: spm | cocoapods | both | unknown
set -euo pipefail
dir="${1:?usage: detect-pm.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
spm=0; pods=0
{ has_glob "$dir" "Package.swift" || has_glob "$dir" "Package.resolved"; } && spm=1
has_glob "$dir" "Podfile" && pods=1
if [ "$spm" -eq 1 ] && [ "$pods" -eq 1 ]; then echo both; exit 0; fi
[ "$spm" -eq 1 ] && { echo spm; exit 0; }
[ "$pods" -eq 1 ] && { echo cocoapods; exit 0; }
echo unknown
