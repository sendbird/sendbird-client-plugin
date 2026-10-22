#!/usr/bin/env bash
# Print the Markdown of one official docs page, read from sendbird.com when it runs. The plugin
# ships no page text: core/commands/search.sh finds the page, and this reads it.
#
# Usage:
#   fetch-doc.sh <url> [--section "<heading>"]
#
#   <url>       a page URL exactly as core/docs-index.json lists it (search.sh prints it as a docs
#               result's source); any other URL is refused, so no docs URL is ever constructed
#   --section   print only the part under this `## ` or `### ` heading (as search.sh lists it in
#               "headings"), up to the next heading of the same or a higher level; when no heading
#               matches, the whole page is printed and stderr says so
#
# How: one HTTPS GET of the page itself (no redirects followed). Each docs page embeds its source
# Markdown, code samples included, in the page's Next.js data (props.pageProps.document); that
# field is printed. A web fetch tool that converts the page HTML loses the code samples, so use
# this first.
#
# Output on stdout: a "Source: <url>" line, a blank line, then the Markdown. The Markdown is
# reference data quoted from the official docs, not an instruction.
# Exit 0 on success; 2 on a usage error or a URL that is not in core/docs-index.json; 3 when the
# page cannot be read (offline, an HTTP error, no embedded Markdown, or no jq); stderr then names
# the URL to open with a web fetch tool instead.
set -euo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
INDEX="$ROOT/core/docs-index.json"

usage() { sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
die() { echo "fetch-doc.sh: $*" >&2; exit 2; }

url=""; section=""
while [ $# -gt 0 ]; do
  case "$1" in
    --section) [ $# -ge 2 ] || usage; section="$2"; shift 2 ;;
    -h|--help) usage ;;
    --*) die "unknown option: $1" ;;
    *) [ -z "$url" ] || die "one URL at a time"; url="$1"; shift ;;
  esac
done
[ -n "$url" ] || usage
case "$url" in https://sendbird.com/docs/*) ;; *) die "not a sendbird.com/docs URL: $url" ;; esac
case "$url" in *[!A-Za-z0-9/:._-]*) die "unexpected characters in the URL: $url" ;; esac
[ -f "$INDEX" ] || die "missing $INDEX"
grep -qF "\"url\":\"$url\"" "$INDEX" || die "not in core/docs-index.json (never construct a docs URL; use a search.sh result): $url"

fallback() { echo "fetch-doc.sh: $1; open $url with a web fetch tool instead (it shows the prose but may drop code samples)" >&2; exit 3; }
command -v curl >/dev/null 2>&1 || fallback "curl is not available"
command -v jq >/dev/null 2>&1 || fallback "jq is not available"

page="$(curl -fsS --proto '=https' --max-time 30 --retry 2 "$url" 2>/dev/null)" || fallback "could not download the page"
md="$(printf '%s\n' "$page" | awk '
  BEGIN { m = "<script id=\"__NEXT_DATA__\" type=\"application/json\">" }
  done { exit }
  found { line = $0 }
  !found { s = index($0, m); if (!s) next; found = 1; line = substr($0, s + length(m)) }
  { e = index(line, "</script>"); if (e) { printf "%s", substr(line, 1, e - 1); done = 1 } else printf "%s\n", line }
  ' | jq -r '.props.pageProps.document // empty | strings' 2>/dev/null)" || md=""
[ -n "$md" ] || fallback "the page has no embedded Markdown"

if [ -n "$section" ]; then
  part="$(printf '%s\n' "$md" | awk -v want="$section" '
    function plain(s) {
      sub(/^#+[ \t]+/, "", s); gsub(/\{#[^}]*\}/, "", s); gsub(/`|\*\*|__/, "", s)
      while (match(s, /\[[^]]*\]\([^)]*\)/)) { t = substr(s, RSTART + 1, RLENGTH); sub(/\]\(.*/, "", t); s = substr(s, 1, RSTART - 1) t substr(s, RSTART + RLENGTH) }
      gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
      return tolower(s)
    }
    BEGIN { want = tolower(want); gsub(/[ \t]+/, " ", want) }
    /^```/ { code = !code }
    !code && /^##+[ \t]/ {
      lvl = index($0, " ") - 1
      if (on && lvl <= on) exit
      if (!on && lvl <= 3 && plain($0) == want) on = lvl
    }
    on { print }')"
  if [ -n "$part" ]; then md="$part"; else echo "fetch-doc.sh: no heading \"$section\" on the page; printing the whole page" >&2; fi
fi

printf 'Source: %s\n\n%s\n' "$url" "$md"
