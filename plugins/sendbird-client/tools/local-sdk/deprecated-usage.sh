#!/usr/bin/env bash
# List the deprecated Sendbird APIs a project uses, read from the SDK files themselves. Nothing is built.
# Usage: deprecated-usage.sh <project-dir> <product> [version] [--download]
#   version     the SDK version to read (Android: the AAR version; default: the one installed version)
#   --download  Android only: when that version's AAR is not in the Gradle cache, fetch it from the
#               public Sendbird Maven repository (DEPRECATED_MAVEN_REPO overrides the URL) into the
#               project's .sendbird-client/cache/aar/. Use it to read the version an upgrade moves to.
# Prints one line per use:  DEPRECATED: <file>:<line>: <name> — <SDK's deprecation message> ...
# and a last line:          CHECKED: <platform> <product> <where the declarations came from>
# or, when the check cannot run: NOT RUN: <reason>  (exit 3). Exit 0 = checked (zero or more uses).
#   JS       the TypeScript language service (lib/js-deprecations.cjs) on the project's sources, with the
#            project's own TypeScript (TS_MODULE overrides it) and the installed packages in node_modules
#   iOS      @available(*, deprecated...) declarations in the installed .swiftinterface (read-surface.sh),
#            matched by name in the project's .swift files
#   Android  members marked Deprecated in the AAR (javap -v), matched by name in .kt and .java files
# A by-name match is a candidate: lines marked "(overloaded: check the call)" need the call's signature.
set -uo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
usage() { echo "usage: deprecated-usage.sh <project-dir> <product> [version] [--download]" >&2; exit 64; }
dir=""; product=""; version=""; download=0
for a in "$@"; do
  case "$a" in
    --download) download=1 ;;
    -*) usage ;;
    *) if [ -z "$dir" ]; then dir="$a"; elif [ -z "$product" ]; then product="$a"; elif [ -z "$version" ]; then version="$a"; else usage; fi ;;
  esac
done
[ -n "$dir" ] && [ -n "$product" ] || usage
[ -d "$dir" ] || { echo "NOT RUN: not a directory: $dir"; exit 3; }
dir="$(cd "$dir" && pwd)"
plat="$(bash "$ROOT/tools/detection/common/detect-platform.sh" "$dir" 2>/dev/null || echo unknown)"
cache="$dir/.sendbird-client/cache/deprecations"; mkdir -p "$cache"
not_run() { echo "NOT RUN: $1"; exit 3; }

case "$plat" in
  js)
    command -v node >/dev/null || not_run "node not found"
    [ -d "$dir/node_modules/@sendbird" ] || ls -d "$dir"/node_modules/sendbird-* >/dev/null 2>&1 \
      || not_run "no Sendbird package in node_modules: install the project's dependencies first (npm install)"
    tsm="${TS_MODULE:-$dir/node_modules/typescript}"
    [ -f "$tsm/package.json" ] || not_run "no TypeScript in the project's node_modules (the check uses the project's own TypeScript)"
    node -e "process.exit(typeof require(process.argv[1]).createLanguageService === 'function' ? 0 : 1)" "$tsm" 2>/dev/null \
      || not_run "the project's TypeScript ($(node -p "require('$tsm/package.json').version" 2>/dev/null)) has no language service API"
    TS_MODULE="$tsm" node "$HERE/lib/js-deprecations.cjs" "$dir" || not_run "the TypeScript check failed"
    echo "CHECKED: js $product node_modules ($(node -p "require('$tsm/package.json').version" 2>/dev/null | sed 's/^/typescript /'))" ;;
  ios)
    bash "$HERE/read-surface.sh" "$dir" "$product" ${version:+"$version"} >/dev/null 2>&1
    surf="$dir/.sendbird-client/cache/$product/api-surface.md"
    grep -q '^- `' "$surf" 2>/dev/null || not_run "no installed $product .swiftinterface found: resolve the Swift packages in Xcode first (read-surface.sh)"
    python3 -I "$HERE/lib/deprecations.py" swift "$surf" > "$cache/$product.tsv"
    python3 -I "$HERE/lib/deprecations.py" usages "$dir" swift "$cache/$product.tsv"
    echo "CHECKED: ios $product $(sed -n 's/.*source: \(.*\) -->.*/\1/p' "$surf" | head -1) ($(wc -l < "$cache/$product.tsv" | tr -d ' ') deprecated declarations)" ;;
  android)
    case "$product" in
      chat) artifact="sendbird-chat";; uikit) artifact="uikit";; ai-agent) artifact="ai-agent-messenger";;
      calls) artifact="sendbird-calls";; desk) artifact="sendbird-desk-android-sdk";; live) artifact="sendbird-live";;
      uikit-compose) artifact="uikit-compose";;
      *) artifact="$product";;
    esac
    search_root="$HOME/.gradle/caches/modules-2/files-2.1/com.sendbird.sdk/$artifact"
    if [ -z "$version" ]; then
      versions="$(find "$search_root" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -V)"
      [ "$(printf '%s\n' "$versions" | sed '/^$/d' | wc -l | tr -d ' ')" = 1 ] \
        || not_run "pass the $artifact version the project declares (Gradle cache has: $(printf '%s' "$versions" | paste -sd, - | sed 's/^$/none/'))"
      version="$versions"
    fi
    aar="$(find "$search_root/$version" "$dir/.sendbird-client/cache/aar" -name "$artifact-$version.aar" -type f 2>/dev/null | head -1)"
    if [ -z "$aar" ] && [ "$download" -eq 1 ]; then
      repo="${DEPRECATED_MAVEN_REPO:-https://repo.sendbird.com/public/maven}"
      mkdir -p "$dir/.sendbird-client/cache/aar"
      aar="$dir/.sendbird-client/cache/aar/$artifact-$version.aar"
      curl -fsSL --max-time 120 "$repo/com/sendbird/sdk/$artifact/$version/$artifact-$version.aar" -o "$aar" \
        || { rm -f "$aar"; not_run "could not download $artifact $version from $repo"; }
    fi
    [ -n "$aar" ] || not_run "$artifact $version is not in the Gradle cache (sync the project once, or pass --download)"
    eval "$(bash "$HERE/android-toolchain.sh" "$dir" 2>/dev/null)"
    command -v javap >/dev/null && command -v jar >/dev/null && command -v unzip >/dev/null || not_run "javap, jar, and unzip are required (a JDK)"
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    unzip -p "$aar" classes.jar > "$tmp/classes.jar" 2>/dev/null || not_run "no classes.jar in $aar"
    jar tf "$tmp/classes.jar" | grep '\.class$' \
      | grep -vE '(^|/)(R|R\$.*|BuildConfig)\.class$|\$[0-9]+(\$|\.class$)|\$WhenMappings\.class$|\$\$|/(internal|impl)/' \
      | sed 's#/#.#g; s#\.class$##' > "$tmp/classes.txt"
    xargs javap -v -public -classpath "$tmp/classes.jar" < "$tmp/classes.txt" > "$tmp/javap.txt" 2>/dev/null
    python3 -I "$HERE/lib/deprecations.py" javap "$tmp/javap.txt" > "$cache/$product.tsv"
    python3 -I "$HERE/lib/deprecations.py" usages "$dir" kotlin "$cache/$product.tsv"
    echo "CHECKED: android $product $artifact-$version.aar ($(wc -l < "$cache/$product.tsv" | tr -d ' ') deprecated declarations)" ;;
  *) not_run "platform not detected for $dir" ;;
esac
exit 0
