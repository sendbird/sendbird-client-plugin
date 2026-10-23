#!/usr/bin/env bash
# Search the GitHub Discussions of one public Sendbird repository for a customization or how-to
# question. Results are community signal: label them as such, never as official spec.
#
# Usage:
#   search-discussions.sh <owner/repo> <keywords...>
#
#   <owner/repo>  a public repository listed under .repos in config/plugin-config.json (for example
#                 sendbird/sendbird-uikit-ios); any other repository is refused
#   <keywords>    English search words (GitHub search syntax); at most 10 results are returned
#
# How: one `gh api graphql` discussion search scoped to that repository. Needs the GitHub CLI
# signed in; it makes no other request and writes no file.
#
# Output on stdout: one JSON object {repo, query, community: true, results: [{title, url, answered,
# createdAt}]}. When the search cannot run, a single line `NOT RUN: <reason>` instead (gh missing
# or signed out, the repository has no Discussions, or the request failed): report the step as not
# run with that reason and answer from the other sources.
# Exit 0 on results (possibly none); 2 on a usage error or a repository not in the config; 3 on NOT RUN.
set -uo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG="$ROOT/config/plugin-config.json"

usage() { sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
not_run() { echo "NOT RUN: $*"; exit 3; }

[ $# -ge 2 ] || usage
repo="$1"; shift
query="$*"
command -v jq >/dev/null 2>&1 || not_run "jq is not installed"
jq -e --arg r "$repo" '[.repos | .. | strings | select(test("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$"))] | index($r)' "$CONFIG" >/dev/null 2>&1 \
  || { echo "search-discussions.sh: $repo is not a public repository listed in config/plugin-config.json .repos" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || not_run "gh (GitHub CLI) is not installed"
gh auth status >/dev/null 2>&1 || not_run "gh is not signed in (gh auth login)"
has="$(gh api "repos/$repo" --jq '.has_discussions' 2>/dev/null)" || not_run "could not read $repo from GitHub"
[ "$has" = "true" ] || not_run "$repo has no GitHub Discussions"

# shellcheck disable=SC2016  # $q is a GraphQL variable, not a shell one
gql='query($q: String!) { search(query: $q, type: DISCUSSION, first: 10) { nodes { ... on Discussion { title url createdAt answer { url } } } } }'
out="$(gh api graphql -f query="$gql" -f q="repo:$repo $query" 2>/dev/null)" || not_run "the GitHub discussion search failed"
jq -e '.data.search.nodes' >/dev/null 2>&1 <<<"$out" || not_run "the GitHub discussion search returned no data"
jq --arg repo "$repo" --arg q "$query" '{repo: $repo, query: $q, community: true,
  results: [.data.search.nodes[] | select(.url) | {title, url, answered: (.answer != null), createdAt}]}' <<<"$out"
