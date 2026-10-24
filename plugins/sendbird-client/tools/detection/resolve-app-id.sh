#!/usr/bin/env bash
# Say where the project's Sendbird App ID comes from, never the value itself.
# Usage: resolve-app-id.sh <project-dir>   -> {"from":"env"} | {"from":"profile"} | {"from":"missing"}
# Order (the same as tools/runtime/run.sh): SENDBIRD_APP_ID unless it is empty or a placeholder, then
# appId in .sendbird-client/profile.json, then the appId another edition of this plugin stored in its
# own state folder in the project (common/sibling-profile.sh), then missing. Unlike run.sh, an all-zero App ID counts as set:
# setup only wires the app to read the value from configuration, so it never needs a working application.
set -euo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
dir="${1:?usage: resolve-app-id.sh <project-dir>}"

# YOUR_..., REPLACE..., <...>: the placeholder text a generated config carries.
is_placeholder() { [[ -z "$1" || "$1" =~ ^(YOUR|REPLACE|\<) ]]; }

if ! is_placeholder "${SENDBIRD_APP_ID:-}"; then
  echo '{"from":"env"}'
  exit 0
fi
profile="$dir/.sendbird-client/profile.json"
app_id="$(jq -r '.appId // empty | strings' "$profile" 2>/dev/null || true)"
if is_placeholder "$app_id"; then
  # shellcheck source=common/sibling-profile.sh
  source "$(cd "$(dirname "$0")" && pwd)/common/sibling-profile.sh"
  app_id="$(sibling_app_id "$dir" ".sendbird-client")"
fi
if is_placeholder "$app_id"; then
  echo '{"from":"missing"}'
else
  echo '{"from":"profile"}'
fi
