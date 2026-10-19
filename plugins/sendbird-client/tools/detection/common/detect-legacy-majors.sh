#!/usr/bin/env bash
# Detect Sendbird SDKs on an older major version. Prints one line per finding,
# "<product> <major> <package>", sorted and de-duplicated; prints nothing when none is found.
#
# Two kinds of evidence:
# - A package name that only an older major was ever published under. The major printed is
#   the last one that name shipped, so the line means "this major or older":
#   - CocoaPods pod SendBirdSDK (trunk versions 2.x-3.x) and Swift package repository
#     sendbird/sendbird-chat-ios-spm (tags v3.x only, product SendBirdSDK).
#     source: https://github.com/sendbird/sendbird-chat-ios-spm/blob/v3.1.60/README.md (L107 pod, L140 import)
#     source: https://github.com/sendbird/sendbird-chat-ios-spm/blob/v3.1.60/Package.swift
#     Swift import: https://github.com/sendbird/SendBird-iOS-Swift/blob/bcc750f879153c6a6eb02687b7c1ade4909829fc/SendBird-iOS/SceneDelegate.swift#L11
#   - Gradle artifact com.sendbird.sdk:sendbird-android-sdk (3.x, repo.sendbird.com/public/maven).
#     source: https://github.com/sendbird/SendBird-SDK-Android/blob/v3.1.27/README.md (L97)
#   - npm package sendbird (2.x-3.x).
#     source: https://github.com/sendbird/SendBird-SDK-JavaScript/blob/v3.1.33/README.md (L150, L156)
#   - npm package sendbird-uikit, the React UIKit before @sendbird/uikit-react (0.x-2.x on the
#     npm registry, https://registry.npmjs.org/sendbird-uikit).
#   The current majors use other names (pod and SPM product SendbirdChatSDK,
#   com.sendbird.sdk:sendbird-chat, @sendbird/chat, @sendbird/uikit-react).
#     source: knowledge/curated/ios/setup.md
# - UIKit, whose package name stayed the same across majors: pod SendBirdUIKit (trunk 1.x-3.x),
#   repository sendbird/sendbird-uikit-ios-spm (tags v2.x and v3.x), com.sendbird.sdk:uikit
#   (1.x-3.x in repo.sendbird.com/public/maven), and @sendbird/uikit-react-native (1.x-3.x on
#   the npm registry). Reported only when the project pins a version below 3 that this script
#   reads exactly: Podfile.lock, Package.resolved, an exact Gradle version, or a package.json range.
#     source: https://github.com/sendbird/sendbird-uikit-ios/blob/v3.18.2/README.md (L113, L129)
set -euo pipefail
dir="${1:?usage: detect-legacy-majors.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/detect-helpers.sh
source "$HERE/../lib/detect-helpers.sh"
found=""
add() { found="$found
$1 $2 $3"; }

# first_file <dir> <name> : the first file with this exact name, outside .git and node_modules
first_file() {
  find "$1" -type f -name "$2" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1
}
# below3 <major> : 0 when the value is a whole number below 3
below3() { case "$1" in (''|*[!0-9]*) return 1 ;; esac; [ "$1" -lt 3 ]; }

# iOS Chat v3. CocoaPods looks pod names up case-sensitively (CocoaPods/Core Source#search
# compares the exact name), so the pod is matched as spelled.
{ has_glob "$dir" "Podfile" && file_contains "$dir" "Podfile" "pod[[:space:]]+['\"]SendBirdSDK['\"/]"; } && add chat 3 SendBirdSDK
{ has_glob "$dir" "Podfile.lock" && file_contains "$dir" "Podfile.lock" '(^|[[:space:]])SendBirdSDK([[:space:]]|$)'; } && add chat 3 SendBirdSDK
file_contains "$dir" "*.swift" 'import[[:space:]]+SendBirdSDK([^A-Za-z0-9_]|$)' && add chat 3 SendBirdSDK
for src in "*.m" "*.h"; do
  file_contains "$dir" "$src" '(#import[[:space:]]*<SendBirdSDK/|@import[[:space:]]+SendBirdSDK)' && add chat 3 SendBirdSDK
done
for f in "Package.swift" "Package.resolved" "*.pbxproj"; do
  file_contains "$dir" "$f" 'sendbird/sendbird-chat-ios-spm' && add chat 3 SendBirdSDK
done

# iOS UIKit below v3, from the resolved version.
lock="$(first_file "$dir" Podfile.lock)"
if [ -n "$lock" ]; then
  m="$(grep -oE 'SendBirdUIKit \([0-9]+\.' "$lock" 2>/dev/null | head -1 | grep -oE '[0-9]+' || true)"
  if below3 "$m"; then add uikit "$m" SendBirdUIKit; fi
fi
res="$(first_file "$dir" Package.resolved)"
if [ -n "$res" ]; then
  # Package.resolved v2/v3 list .pins[] with identity and location; v1 lists .object.pins[]
  # with package and repositoryURL.
  m="$(jq -r '[.pins[]?, .object.pins[]? | select(((.identity // .package // "") | ascii_downcase) == "sendbird-uikit-ios-spm" or ((.location // .repositoryURL // "") | test("sendbird/sendbird-uikit-ios-spm"; "i"))) | .state.version // empty] | .[0] // empty' "$res" 2>/dev/null | cut -d. -f1 || true)"
  if below3 "$m"; then add uikit "$m" sendbird-uikit-ios-spm; fi
fi

# Android: the v3 Chat artifact, and UIKit with an exact version below 3.
while IFS=' ' read -r artifact version; do
  if [ "$artifact" = "sendbird-android-sdk" ]; then
    add chat 3 com.sendbird.sdk:sendbird-android-sdk
  elif [ "$artifact" = "uikit" ] && below3 "${version%%.*}"; then
    add uikit "${version%%.*}" com.sendbird.sdk:uikit
  fi
done < <(gradle_sendbird_deps "$dir")

# JS: the v3 Chat package and the React UIKit v2 package by name; React Native UIKit from the
# major of its package.json range (^2.4.0, ~2.4.0, 2.4.0, >=2.4.0).
if [ -f "$dir/package.json" ]; then
  if pkgjson_has_dep "$dir" "sendbird"; then add chat 3 sendbird; fi
  if pkgjson_has_dep "$dir" "sendbird-uikit"; then add uikit 2 sendbird-uikit; fi
  spec="$(jq -r '((.dependencies // {}) + (.devDependencies // {}))["@sendbird/uikit-react-native"] // empty' "$dir/package.json" 2>/dev/null || true)"
  m="$(printf '%s' "$spec" | sed -nE 's/^[[:space:]]*(\^|~|>=|=)?[[:space:]]*v?([0-9]+)(\..*)?$/\2/p')"
  if below3 "$m"; then add uikit "$m" @sendbird/uikit-react-native; fi
fi

printf '%s\n' "$found" | sed '/^$/d' | sort -u
