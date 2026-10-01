#!/usr/bin/env bash
# Read a customer-INSTALLED Sendbird product's public surface and cache it locally.
# Usage: read-surface.sh <project-dir> <product> [resolved-version]
# Writes <project-dir>/.sendbird-client/cache/<product>/api-surface.md (gitignored; never committed).
set -euo pipefail
dir="${1:?usage: read-surface.sh <project-dir> <product> [resolved-version]}"; product="${2:?product}"; version="${3:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
plat="$(bash "$ROOT/tools/detection/common/detect-platform.sh" "$dir" 2>/dev/null || echo unknown)"
host="unknown"
[ "$plat" = "js" ] && host="$(bash "$ROOT/tools/detection/js/detect-host.sh" "$dir" 2>/dev/null || echo unknown)"
out="$dir/.sendbird-client/cache/$product/api-surface.md"; mkdir -p "$(dirname "$out")"
# shellcheck source=lib/render.sh
source "$HERE/lib/render.sh"
case "$plat" in
  js)
    case "$product" in
      chat) pkg="@sendbird/chat";;
      uikit) if [ "$host" = "react-native" ]; then pkg="@sendbird/uikit-react-native"; else pkg="@sendbird/uikit-react"; fi;;
      calls) if [ -d "$dir/node_modules/@sendbird/calls-react-native" ]; then pkg="@sendbird/calls-react-native"; else pkg="sendbird-calls"; fi;;
      desk) pkg="sendbird-desk";;
      live) pkg="@sendbird/live";;
      ai-agent) if [ -d "$dir/node_modules/@sendbird/ai-agent-messenger-react-native" ]; then pkg="@sendbird/ai-agent-messenger-react-native"; else pkg="@sendbird/ai-agent-messenger-react"; fi;;
      *) pkg="@sendbird/$product";;
    esac
    pkg_dir="$dir/node_modules/$pkg"
    # The whole package (every import path in "exports"), not one entry file.
    if [ -f "$pkg_dir/package.json" ]; then bash "$HERE/read-dts.sh" "$pkg_dir" "$pkg" "$dir" > "$out"
    else render_empty "$product" "$pkg not in node_modules" > "$out"; fi
    ;;
  ios)
    # Module names verified in the public SPM packages (sendbird-chat-sdk-ios,
    # sendbird-uikit-ios-spm, sendbird-live-sdk-ios). Match on `<Module>.swiftmodule/`,
    # never on the whole path: a project folder named `uikit-demo` must not turn the
    # Chat interface into a UIKit candidate.
    case "$product" in
      chat) module="SendbirdChatSDK";; uikit) module="SendbirdUIKit";; live) module="SendbirdLiveSDK";; *) module="";;
    esac
    # Where an installed xcframework lives: CocoaPods (Pods/), SwiftPM CLI
    # (.build/artifacts), and Xcode's SPM cache (DerivedData/<Project>-<hash>/
    # SourcePackages/artifacts), whose info.plist WorkspacePath points into this project.
    dir_abs="$(cd "$dir" && pwd)"
    roots=("$dir/Pods" "$dir/.build/artifacts" "$dir/.build/checkouts")
    dd_root="${XCODE_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"
    if [ -d "$dd_root" ]; then
      while IFS= read -r plist; do
        ws="$(plutil -extract WorkspacePath raw -o - "$plist" 2>/dev/null \
          || sed -n '/<key>WorkspacePath<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$plist" 2>/dev/null || true)"
        case "$ws" in "$dir_abs"/*) roots+=("$(dirname "$plist")/SourcePackages/artifacts") ;; esac
      done < <(ls -t "$dd_root"/*/info.plist 2>/dev/null || true)
    fi
    # Every xcframework ships one interface per slice plus `.private` and `.package`
    # variants next to the public one. Never read those two; prefer the device slice
    # (ios-arm64/.../arm64-apple-ios.swiftinterface), then any iOS device slice, then the
    # simulator, then other platforms (macOS). Ties keep the root order above.
    candidates() {
      local i=0 r
      for r in "${roots[@]}" "$dir"; do
        i=$((i + 1))
        [ -d "$r" ] || continue
        find "$r" -name '*.swiftinterface' 2>/dev/null | sed "s#^#$i	#"
      done
    }
    si="$(candidates \
      | grep -vE '\.(private|package)\.swiftinterface$' \
      | awk -F '\t' -v mod="$module" -v prod="$product" '{
          n = split($2, parts, "/"); sm = ""
          for (k = n; k >= 1; k--) if (parts[k] ~ /\.swiftmodule$/) { sm = parts[k]; break }
          sub(/\.swiftmodule$/, "", sm)
          if (mod != "" ? sm != mod : index(tolower(sm), tolower(prod)) == 0) next
          r = 4
          if ($2 ~ /\/ios-arm64\/.*\/arm64-apple-ios\.swiftinterface$/) r = 0
          else if ($2 ~ /-apple-ios\.swiftinterface$/) r = 1
          else if ($2 ~ /-apple-ios-simulator\.swiftinterface$/) r = 2
          print r "\t" $1 "\t" $2 }' \
      | sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3 | head -1 | cut -f3- || true)"
    if [ -n "$si" ]; then bash "$HERE/read-swiftinterface.sh" "$si" "$product" > "$out"
    else render_empty "$product" "no .swiftinterface found (install via SPM/CocoaPods first)" > "$out"; fi
    ;;
  android)
    jv="$(find "$dir" -name "*$product*.javap.txt" 2>/dev/null | head -1 || true)"
    if [ -n "$jv" ]; then bash "$HERE/read-javap.sh" "$jv" "$product" > "$out"
    else
      case "$product" in
        chat) artifact="sendbird-chat";; uikit) artifact="uikit";; ai-agent) artifact="ai-agent-messenger";;
        calls) artifact="sendbird-calls";; desk) artifact="sendbird-desk-android-sdk";; live) artifact="sendbird-live";;
        *) artifact="$product";;
      esac
      search_root="$HOME/.gradle/caches/modules-2/files-2.1/com.sendbird.sdk/$artifact"
      if [ -n "$version" ]; then
        aar="$(find "$dir" "$search_root/$version" -name "${artifact}-${version}.aar" -type f 2>/dev/null | head -1 || true)"
      else
        versions="$(find "$search_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -Vu || true)"
        count="$(printf '%s\n' "$versions" | sed '/^$/d' | wc -l | tr -d ' ')"
        if [ "$count" -gt 1 ]; then
          render_empty "$product" "multiple installed $artifact versions found ($(printf '%s' "$versions" | paste -sd, -)); pass the resolved version as the third argument" > "$out"
          echo "wrote $out"
          exit 0
        fi
        version="$(printf '%s\n' "$versions" | tail -1)"
        aar="$(find "$dir" "$search_root/$version" -name "${artifact}-${version}.aar" -type f 2>/dev/null | head -1 || true)"
      fi
      if [ -n "${aar:-}" ]; then bash "$HERE/read-aar.sh" "$aar" "$product" > "$out"
      else render_empty "$product" "no installed AAR found; resolve the Gradle dependency version and pass it as the third argument" > "$out"; fi
    fi
    ;;
  *)
    render_empty "$product" "platform not detected for $dir" > "$out"
    ;;
esac
echo "wrote $out"
