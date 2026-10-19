#!/usr/bin/env bash
# Pure detection command (core-lite). Prints freshly detected project facts as
# JSON to stdout. No file reads or writes beyond the target project's own
# source tree — it never touches .sendbird-client/profile.json.
#
# This is the side-effect-free half of what tools/detection/detect.sh used to
# do in one step. Splitting it out means a future non-Claude-Code caller (a
# standalone CLI) can run detection without inheriting the plugin's storage
# choice, and it removes the class of bug where "detect" silently discards a
# previously stored field it doesn't itself produce (see core/README.md).
#
# Usage: detect.sh <project-dir>
# Output shape: see core/schemas/detection-result.schema.json
set -euo pipefail
dir="${1:?usage: detect.sh <project-dir>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DETECT="$(cd "$HERE/../../tools/detection" && pwd)"

platform="$(bash "$DETECT/common/detect-platform.sh" "$dir")"
host="unknown"; pm="unknown"; dep="unknown"; life="unknown"; interop="none"
case "$platform" in
  ios)
    host="$(bash "$DETECT/ios/detect-host.sh" "$dir")"
    pm="$(bash "$DETECT/ios/detect-pm.sh" "$dir")"
    dep="$(bash "$DETECT/ios/detect-deployment-target.sh" "$dir")"
    life="$(bash "$DETECT/ios/detect-lifecycle.sh" "$dir")"
    interop="$(bash "$DETECT/ios/detect-interop.sh" "$dir")" ;;
  android)
    host="$(bash "$DETECT/android/detect-host.sh" "$dir")"
    pm="$(bash "$DETECT/android/detect-gradle.sh" "$dir")"
    dep="$(bash "$DETECT/android/detect-min-sdk.sh" "$dir")" ;;
  js)
    host="$(bash "$DETECT/js/detect-host.sh" "$dir")"
    pm="$(bash "$DETECT/js/detect-pm.sh" "$dir")" ;;
esac
existing="$(bash "$DETECT/common/detect-existing-integration.sh" "$dir")"
present="$(printf '%s' "$existing" | sed -nE 's/.*present=([a-z]+).*/\1/p')"
ever="$(printf '%s' "$existing" | sed -nE 's/.*version=([^ ]+).*/\1/p')"
products="$(bash "$DETECT/common/detect-products.sh" "$dir")"
# Older majors: "<product> <major> <package>" lines -> [{product, major, package}]
legacy_json="$(bash "$DETECT/common/detect-legacy-majors.sh" "$dir" \
  | jq -R -s -c 'split("\n") | map(select(length > 0) | split(" ") | {product: .[0], major: (.[1] | tonumber), package: .[2]})')"
region="$(bash "$DETECT/common/detect-region.sh" "$dir")"
push_provider="$(bash "$DETECT/tier2/detect-push-provider.sh" "$dir")"
state_management="$(bash "$DETECT/tier2/detect-state-management.sh" "$dir")"
app_id_source="$(bash "$DETECT/tier2/detect-app-id-source.sh" "$dir")"
if [ "$products" = "unknown" ] || [ -z "$products" ]; then prod_json='[]';
else prod_json="$(printf '%s' "$products" | jq -R 'split(",")')"; fi

jq -n \
  --arg platform "$platform" --arg host "$host" --arg pm "$pm" \
  --arg dep "$dep" --arg life "$life" --arg interop "$interop" \
  --arg present "$present" --arg ever "$ever" --arg region "$region" \
  --arg pushProvider "$push_provider" --arg stateManagement "$state_management" --arg appIdSource "$app_id_source" \
  --argjson products "$prod_json" --argjson legacyMajors "$legacy_json" \
  '{
     platform: $platform, host: $host, packageManager: $pm,
     deploymentTarget: $dep, lifecycle: $life, interop: $interop,
     existingIntegration: { present: ($present=="true"), version: $ever },
     products: $products, legacyMajors: $legacyMajors, region: $region,
     tier2: { pushProvider: $pushProvider, stateManagement: $stateManagement, appIdSource: $appIdSource },
     schemaVersion: 1, detectedAt: (now | todateiso8601)
   }'
