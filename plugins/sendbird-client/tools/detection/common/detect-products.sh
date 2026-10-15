#!/usr/bin/env bash
# Detect Sendbird products. Prints sorted comma list of: chat uikit ai-agent desk calls live
# (auth is folded into chat, never reported standalone).
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
# Bash 3.2 (stock macOS /bin/bash) has no associative arrays: collect the names in a
# space-separated string and remove duplicates with sort -u at the end.
found=""
mark() { found="$found $1"; }
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
# Calls and Desk modules spell the brand with a capital B (knowledge/curated/ios/products/calls.md,
# desk.md); accept both spellings.
file_contains "$dir" "*.swift" 'import[[:space:]]+Send[Bb]irdCalls' && mark calls
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdAIAgent' && mark ai-agent
file_contains "$dir" "*.swift" 'import[[:space:]]+Send[Bb]irdDesk' && mark desk
file_contains "$dir" "*.swift" 'import[[:space:]]+SendbirdLive' && mark live
{ has_glob "$dir" "Podfile" && file_contains "$dir" "Podfile" "pod[[:space:]]+'SendbirdUIKit'"; } && mark uikit
{ has_glob "$dir" "Podfile" && file_contains "$dir" "Podfile" "pod[[:space:]]+'SendbirdChat"; } && mark chat
# Android: Gradle build files and the version catalog (gradle/libs.versions.toml), in the
# "com.sendbird.sdk:<artifact>" form or as group = "com.sendbird.sdk", name = "<artifact>".
# Artifacts from knowledge/curated/android/setup.md "Packaging (Gradle)" and hosts/compose.md.
while IFS= read -r artifact; do
  case "$artifact" in
    sendbird-chat) mark chat;; uikit|uikit-compose) mark uikit;; ai-agent-messenger) mark ai-agent;;
    sendbird-calls) mark calls;; sendbird-desk-android-sdk) mark desk;; sendbird-live) mark live;;
  esac
done < <(gradle_sendbird_artifacts "$dir")
file_contains "$dir" "*.gradle*" 'com\.sendbird:uikit' && mark uikit
# Kotlin and Java sources: package names from the imports in knowledge/curated/android.
for src in "*.kt" "*.java"; do
  file_contains "$dir" "$src" 'com\.sendbird\.android' && mark chat
  file_contains "$dir" "$src" 'com\.sendbird\.uikit' && mark uikit
  file_contains "$dir" "$src" 'com\.sendbird\.sdk\.aiagent' && mark ai-agent
  file_contains "$dir" "$src" 'com\.sendbird\.calls' && mark calls
  file_contains "$dir" "$src" 'com\.sendbird\.live' && mark live
done
out="$(printf '%s\n' $found | sort -u | paste -sd, -)"
[ -n "$out" ] && echo "$out" || echo "unknown"
