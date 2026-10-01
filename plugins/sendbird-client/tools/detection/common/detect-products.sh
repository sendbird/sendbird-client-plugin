#!/usr/bin/env bash
# Detect Sendbird products. Prints sorted comma list of: chat uikit ai-agent desk calls live
# (auth is folded into chat, never reported standalone).
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
declare -A found
mark() { found["$1"]=1; }
if [ -f "$dir/package.json" ]; then
  pkgjson_has_dep "$dir" "@sendbird/chat" && mark chat
  { pkgjson_has_dep "$dir" "@sendbird/uikit-react" || pkgjson_has_dep "$dir" "@sendbird/uikit-react-native"; } && mark uikit
  pkgjson_has_dep "$dir" "sendbird-calls" && mark calls
  pkgjson_has_dep "$dir" "@sendbird/calls-react-native" && mark calls
  { pkgjson_has_dep "$dir" "@sendbird/ai-agent-messenger-react" || pkgjson_has_dep "$dir" "@sendbird/ai-agent-messenger-react-native"; } && mark ai-agent
  pkgjson_has_dep "$dir" "sendbird-desk" && mark desk
  pkgjson_has_dep "$dir" "@sendbird/live" && mark live
fi
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdChatSDK' && mark chat
file_contains "$dir" "*.swift" 'import[[:space:]]+(SendbirdUIKit|SendbirdSwiftUI)' && mark uikit
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdCalls' && mark calls
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdAIAgent' && mark ai-agent
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdDesk' && mark desk
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdLive' && mark live
{ has_glob "$dir" "Podfile" && file_contains "$dir" "Podfile" "pod[[:space:]]+'SendbirdUIKit'"; } && mark uikit
{ has_glob "$dir" "Podfile" && file_contains "$dir" "Podfile" "pod[[:space:]]+'SendbirdChat"; } && mark chat
file_contains "$dir" "*.gradle*" 'com\.sendbird\.sdk:uikit|com\.sendbird:uikit' && mark uikit
file_contains "$dir" "*.kt" 'com\.sendbird\.android' && mark chat
file_contains "$dir" "*.kt" 'com\.sendbird\.calls' && mark calls
out="$(printf '%s\n' "${!found[@]}" | sort | paste -sd, -)"
[ -n "$out" ] && echo "$out" || echo "unknown"
