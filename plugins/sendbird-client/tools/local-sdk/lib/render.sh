#!/usr/bin/env bash
# Shared rendering for local-SDK readers. Source this file.
render_header() {
  local title="$1" src="$2"
  echo "<!-- local-read: customer-installed SDK, not redistributed. source: $src -->"
  echo "# ${title} — Public API Surface (read from your installed SDK)"
  echo
}
render_empty() {
  local title="$1" reason="$2"
  render_header "$title" "(none)"
  echo "_Public SDK surface unavailable: ${reason}. Resolve the stated condition, then re-run._"
}
