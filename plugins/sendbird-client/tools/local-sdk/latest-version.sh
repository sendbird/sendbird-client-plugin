#!/usr/bin/env bash
# Look up the newest published version of a Sendbird SDK in its registry. Never answer from memory.
# Usage: latest-version.sh npm   <package>                     [--major N]   (npm registry)
#        latest-version.sh spm   <https://github.com/<org>/<repo>> [--major N]   (git tags)
#        latest-version.sh maven <artifact or group:artifact>    [--major N] [--repo URL]
#             (maven-metadata.xml; group defaults to com.sendbird.sdk, repo to the public Sendbird
#              Maven repository; pass --repo with the URL the project's settings.gradle declares)
# Prints one JSON object: {registry, name, latest, latestInMajor, major, versions, source}.
# Only stable versions (x.y.z, optional leading v) count; prereleases (-beta, -rc) are skipped.
# Exit 0 found, 1 the registry could not be read (JSON with "error"), 64 bad arguments.
set -uo pipefail
usage() { echo "usage: latest-version.sh <npm|spm|maven> <name> [--major N] [--repo URL]" >&2; exit 64; }
kind="${1:-}"; name="${2:-}"; [ -n "$kind" ] && [ -n "$name" ] || usage; shift 2
major=""; repo="https://repo.sendbird.com/public/maven"
while [ $# -gt 0 ]; do
  case "$1" in
    --major) [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]] || usage; major="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || usage; repo="${2%/}"; shift 2 ;;
    *) usage ;;
  esac
done
fail() { jq -nc --arg r "$kind" --arg n "$name" --arg e "$1" '{registry:$r, name:$n, error:$e}'; exit 1; }
case "$kind" in
  npm)
    command -v npm >/dev/null || fail "npm not found"
    raw="$(npm view "$name" versions --json 2>/dev/null)" || fail "npm view $name failed"
    list="$(jq -r 'if type == "array" then .[] else . end' <<<"$raw")"
    source="npm view $name versions" ;;
  spm)
    [[ "$name" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || usage
    command -v git >/dev/null || fail "git not found"
    list="$(git ls-remote --tags --refs "$name" 2>/dev/null | awk '{print $2}' | sed 's#^refs/tags/##')" || true
    [ -n "$list" ] || fail "git ls-remote --tags $name returned no tags"
    source="git ls-remote --tags $name" ;;
  maven)
    case "$name" in *:*) group="${name%%:*}"; artifact="${name#*:}" ;; *) group="com.sendbird.sdk"; artifact="$name" ;; esac
    url="$repo/$(tr . / <<<"$group")/$artifact/maven-metadata.xml"
    xml="$(curl -fsSL --max-time 30 "$url" 2>/dev/null)" || fail "could not read $url"
    list="$(sed -n 's#.*<version>\([^<]*\)</version>.*#\1#p' <<<"$xml")"
    source="$url" ;;
  *) usage ;;
esac
python3 -I -c '
import json, re, sys
kind, name, major, source = sys.argv[1:5]
seen = {}
for v in sys.stdin.read().split():
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", v.strip())
    if m:
        seen[tuple(int(x) for x in m.groups())] = v.strip().lstrip("v")
keys = sorted(seen)
if not keys:
    print(json.dumps({"registry": kind, "name": name, "error": "no stable versions found", "source": source})); sys.exit(1)
inmajor = [k for k in keys if major and k[0] == int(major)]
print(json.dumps({"registry": kind, "name": name, "latest": seen[keys[-1]],
                  "latestInMajor": seen[inmajor[-1]] if inmajor else None, "major": int(major) if major else None,
                  "versions": len(keys), "source": source}))
' "$kind" "$name" "$major" "$source" <<<"$list"
