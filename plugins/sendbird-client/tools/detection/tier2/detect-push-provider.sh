#!/usr/bin/env bash
# Tier-2 best-effort: push provider. apns-p8|apns-cert|fcm|web-push|unknown
set -euo pipefail
dir="${1:?usage}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
has_glob "$dir" "*.p8" && { echo apns-p8; exit 0; }
has_glob "$dir" "google-services.json" "GoogleService-Info.plist" && { echo fcm; exit 0; }
# An Android app that already receives FCM: a messaging service class, or the firebase-messaging
# dependency, even before google-services.json is downloaded.
fcm_class='(extends|:)[[:space:]]*(FirebaseMessagingService|SendbirdPushHandler)[[:space:]]*(\(|\{|$)'
{ file_contains "$dir" "*.kt" "$fcm_class" || file_contains "$dir" "*.java" "$fcm_class"; } && { echo fcm; exit 0; }
gradle_files "$dir" | xargs grep -lE 'firebase-messaging' 2>/dev/null | grep -q . && { echo fcm; exit 0; }
file_contains "$dir" "*.swift" 'import[[:space:]]+PushKit|UNUserNotificationCenter' && { echo apns-cert; exit 0; }
echo unknown
