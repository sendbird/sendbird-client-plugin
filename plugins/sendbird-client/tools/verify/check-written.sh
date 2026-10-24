#!/usr/bin/env bash
# Type-check the source files this run wrote, without building the app (docs/AGENT_CONTRACT.md section 3,
# "Type-check the Chat SDK screens you wrote"). Only the chat-ui=chat-sdk path calls it: screens written on
# the Chat SDK alone have no plugin-built template behind every line, and each demo round produced compile
# errors that nobody saw until the app was built (a Kotlin nullable return, a missing orEmpty(), a
# non-optional Swift value in `if let`).
#
# Usage: check-written.sh <project-dir> <written file>...
#
# The files pick the checker, and the checker runs on the project's own toolchain and configuration:
#   .ts .tsx        the project's TypeScript: node_modules/.bin/tsc --noEmit -p <the tsconfig that includes the file>
#   .kt .java       the module's Gradle compile task only: ./gradlew :<module>:compileDebugKotlin
#                   (compileDebugJavaWithJavac for Java), with the JDK and Android SDK from
#                   tools/local-sdk/android-toolchain.sh
#   .swift          swiftc -typecheck on the target's Swift files against the resolved binary Swift
#                   packages: CocoaPods' Pods/, or the project's own DerivedData folder (the one Xcode
#                   uses, from xcodebuild -showBuildSettings); when that has no packages yet,
#                   xcodebuild -resolvePackageDependencies resolves them there. An XcodeGen project.yml
#                   gets its Xcode project generated under <stateDir>/typecheck/, not next to project.yml
# Nothing is installed, and no app is built, signed, or launched.
#
# Output: one JSON line per platform on stdout, for example
#   {"check":"typecheck","platform":"android","result":"fail","tool":"gradlew :app:compileDebugKotlin",
#    "seconds":11,"files":2,"errors":[{"file":"app/src/.../A.kt","line":78,"column":70,"message":"..."}],
#    "otherErrors":0,"reason":""}
# result is pass, fail (errors lists the written files' errors, otherErrors counts errors in other files),
# or not-run (reason says why: no tsconfig, no Gradle wrapper, packages not resolved, a module only a
# build can provide, a timeout, ...).
# Exit: 0 every platform passed, 1 a platform failed, 2 nothing failed but a platform was not run,
# 64 bad arguments. SENDBIRD_TYPECHECK_TIMEOUT (seconds, default 300) limits each checker.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

[ $# -ge 2 ] || { echo "usage: check-written.sh <project-dir> <written file>..." >&2; exit 64; }
[ -d "$1" ] || { echo "check-written: no such project folder: $1" >&2; exit 64; }
command -v jq >/dev/null || { echo "check-written: jq is required" >&2; exit 64; }
PROJECT="$(cd "$1" && pwd -P)"; shift
LIMIT="${SENDBIRD_TYPECHECK_TIMEOUT:-300}"
STATE_DIR="$(jq -r '.stateDir // ".sendbird-client"' "$ROOT/config/plugin-config.json" 2>/dev/null)"
[ -n "$STATE_DIR" ] || STATE_DIR=".sendbird-client"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Written files, absolute and existing, grouped by platform.
js_files=(); android_files=(); ios_files=()
for f in "$@"; do
  case "$f" in /*) p="$f" ;; *) p="$PROJECT/$f" ;; esac
  [ -f "$p" ] || continue
  p="$(cd "$(dirname "$p")" && pwd -P)/$(basename "$p")"
  case "$p" in "$PROJECT"/*) ;; *) continue ;; esac
  case "$p" in
    *.ts|*.tsx) js_files+=("$p") ;;
    *.kt|*.java) android_files+=("$p") ;;
    *.swift) ios_files+=("$p") ;;
  esac
done

rel() { local p="$1"; printf '%s' "${p#"$PROJECT"/}"; }

# run_limited <log> <cmd...> : runs the command with output in <log>; returns its status, or 124 after
# $LIMIT seconds (the command is stopped).
run_limited() {
  local log="$1"; shift
  "$@" > "$log" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$LIMIT" ]; then
      pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null; return 124
    fi
    sleep 1; waited=$((waited + 1))
  done
  wait "$pid"
}

# emit <platform> <result> <tool> <seconds> <file count> <errors tsv> <other count> <reason>
# errors tsv: file<TAB>line<TAB>column<TAB>message per line (file relative to the project)
emit() {
  local errs="[]"
  if [ -s "$6" ]; then
    errs="$(head -20 "$6" | jq -R -s 'split("\n") | map(select(length > 0) | split("\t")
      | {file: .[0], line: (.[1] | tonumber? // 0), column: (.[2] | tonumber? // 0), message: (.[3:] | join("\t") | .[0:300])})')"
  fi
  jq -c -n --arg p "$1" --arg r "$2" --arg t "$3" --argjson s "$4" --argjson n "$5" --argjson e "$errs" \
    --argjson o "$7" --arg why "$8" \
    '{check: "typecheck", platform: $p, result: $r, tool: $t, seconds: $s, files: $n, errors: $e, otherErrors: $o, reason: $why}'
}

# split_errors <all errors tsv> <written files list> <mine tsv> : keeps the written files' errors in
# <mine tsv> and prints how many other errors there were
split_errors() {
  : > "$3"
  local other=0 file
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%$'\t'*}"
    if grep -qxF "$file" "$2"; then printf '%s\n' "$line" >> "$3"; else other=$((other + 1)); fi
  done < "$1"
  printf '%s' "$other"
}

worst=0   # 0 pass, 2 not-run, 1 fail
note() { case "$1" in fail) worst=1 ;; not-run) [ "$worst" = 1 ] || worst=2 ;; esac; }

# ---------------------------------------------------------------- TypeScript
check_js() {
  local n=${#js_files[@]} start=$SECONDS dir tsc="" tsdir="" cfg="" f
  # the folder with the project's own TypeScript, nearest to the first written file
  dir="$(dirname "${js_files[0]}")"
  while :; do
    if [ -x "$dir/node_modules/.bin/tsc" ]; then tsc="$dir/node_modules/.bin/tsc"; tsdir="$dir"; break; fi
    [ "$dir" = "$PROJECT" ] || [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  if [ -z "$tsc" ]; then
    emit js not-run "tsc" 0 "$n" /dev/null 0 "TypeScript is not installed in the project (no node_modules/.bin/tsc); nothing was installed for this check"; note not-run; return
  fi
  [ -f "$tsdir/tsconfig.json" ] || { emit js not-run "tsc" 0 "$n" /dev/null 0 "no tsconfig.json next to the project's TypeScript"; note not-run; return; }
  # the tsconfig whose files include a written file: tsconfig.json, or one it references (a Vite
  # tsconfig.json lists no files and references tsconfig.app.json)
  local candidates=("tsconfig.json") refs c
  (cd "$tsdir" && "$tsc" --showConfig -p tsconfig.json > "$TMP/show.json" 2>/dev/null)
  refs="$(jq -r '.references[]?.path // empty' "$TMP/show.json" 2>/dev/null)"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    [ -d "$tsdir/$c" ] && c="$c/tsconfig.json"
    candidates+=("${c#./}")
  done <<< "$refs"
  for c in "${candidates[@]}"; do
    [ -f "$tsdir/$c" ] || continue
    (cd "$tsdir" && "$tsc" --showConfig -p "$c" > "$TMP/show.json" 2>/dev/null) || continue
    jq -r '.files[]?' "$TMP/show.json" 2>/dev/null | sed 's#^\./##' > "$TMP/cfgfiles"
    for f in "${js_files[@]}"; do
      if grep -qxF "${f#"$tsdir"/}" "$TMP/cfgfiles"; then cfg="$c"; break 2; fi
    done
  done
  if [ -z "$cfg" ]; then
    emit js not-run "tsc" $((SECONDS - start)) "$n" /dev/null 0 "no tsconfig in $(rel "$tsdir")/ includes the written files"; note not-run; return
  fi
  local tool="tsc --noEmit -p $cfg" rc
  (cd "$tsdir" && run_limited "$TMP/tsc.log" "$tsc" --noEmit --pretty false -p "$cfg"); rc=$?
  local secs=$((SECONDS - start))
  if [ "$rc" = 124 ]; then emit js not-run "$tool" "$secs" "$n" /dev/null 0 "stopped after ${LIMIT} s"; note not-run; return; fi
  # file(line,col): error TS1234: message   (paths relative to the tsconfig folder)
  sed -nE 's/^([^(]+)\(([0-9]+),([0-9]+)\): error (TS[0-9]+: .*)$/\1\t\2\t\3\t\4/p' "$TMP/tsc.log" | while IFS=$'\t' read -r p l c m; do
    case "$p" in /*) ;; *) p="$tsdir/$p" ;; esac
    printf '%s\t%s\t%s\t%s\n' "$(rel "$p")" "$l" "$c" "$m"
  done > "$TMP/js.all"
  for f in "${js_files[@]}"; do rel "$f"; echo; done > "$TMP/js.mine.list"
  local other; other="$(split_errors "$TMP/js.all" "$TMP/js.mine.list" "$TMP/js.mine")"
  if [ -s "$TMP/js.mine" ]; then emit js fail "$tool" "$secs" "$n" "$TMP/js.mine" "$other" ""; note fail
  elif [ "$rc" = 0 ] || [ "$other" -gt 0 ]; then emit js pass "$tool" "$secs" "$n" /dev/null "$other" ""; note pass
  else emit js not-run "$tool" "$secs" "$n" /dev/null 0 "tsc stopped without a type error: $(tail -1 "$TMP/tsc.log" | cut -c1-200)"; note not-run
  fi
}

# ---------------------------------------------------------------- Android (Gradle)
check_android() {
  local n=${#android_files[@]} start=$SECONDS dir groot="" mdir="" f kotlin=0
  dir="$(dirname "${android_files[0]}")"
  while :; do
    [ -z "$mdir" ] && { [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ]; } && mdir="$dir"
    if [ -x "$dir/gradlew" ]; then groot="$dir"; break; fi
    [ "$dir" = "$PROJECT" ] || [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  if [ -z "$groot" ]; then emit android not-run "gradlew" 0 "$n" /dev/null 0 "no Gradle wrapper (gradlew) in the project"; note not-run; return; fi
  [ -n "$mdir" ] || mdir="$groot"
  for f in "${android_files[@]}"; do case "$f" in *.kt) kotlin=1 ;; esac; done
  local module="" task
  [ "$mdir" != "$groot" ] && module=":$(printf '%s' "${mdir#"$groot"/}" | tr '/' ':')"
  if [ "$kotlin" = 1 ]; then task="$module:compileDebugKotlin"; else task="$module:compileDebugJavaWithJavac"; fi
  local tool="gradlew $task" envs
  envs="$(bash "$ROOT/tools/local-sdk/android-toolchain.sh" "$groot" 2>/dev/null)"
  if printf '%s' "$envs" | grep -q '^# missing:'; then
    emit android not-run "$tool" 0 "$n" /dev/null 0 "$(printf '%s' "$envs" | grep '^# missing:' | head -1 | sed 's/^# missing:[[:space:]]*/no /') (tools/local-sdk/android-toolchain.sh)"; note not-run; return
  fi
  local rc
  ( eval "$envs"; cd "$groot" && run_limited "$TMP/gradle.log" ./gradlew --no-daemon -q --console=plain "$task" ); rc=$?
  local secs=$((SECONDS - start))
  if [ "$rc" = 124 ]; then emit android not-run "$tool" "$secs" "$n" /dev/null 0 "stopped after ${LIMIT} s"; note not-run; return; fi
  # Kotlin 2: e: file:///abs/A.kt:78:70 message   Kotlin 1: e: /abs/A.kt: (78, 70): message
  # javac:    /abs/A.java:12: error: message
  {
    sed -nE 's#^e: (file://)?(/[^:]+):([0-9]+):([0-9]+) (.*)$#\2\t\3\t\4\t\5#p' "$TMP/gradle.log"
    sed -nE 's#^e: (/[^:]+): \(([0-9]+), ([0-9]+)\): (.*)$#\1\t\2\t\3\t\4#p' "$TMP/gradle.log"
    sed -nE 's#^(/[^:]+\.java):([0-9]+): error: (.*)$#\1\t\2\t0\t\3#p' "$TMP/gradle.log"
  } | while IFS=$'\t' read -r p l c m; do
    p="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)/$(basename "$p")"
    printf '%s\t%s\t%s\t%s\n' "$(rel "$p")" "$l" "$c" "$m"
  done > "$TMP/an.all"
  for f in "${android_files[@]}"; do rel "$f"; echo; done > "$TMP/an.mine.list"
  local other; other="$(split_errors "$TMP/an.all" "$TMP/an.mine.list" "$TMP/an.mine")"
  if [ -s "$TMP/an.mine" ]; then emit android fail "$tool" "$secs" "$n" "$TMP/an.mine" "$other" ""; note fail
  elif [ "$rc" = 0 ]; then emit android pass "$tool" "$secs" "$n" /dev/null 0 ""; note pass
  elif [ "$other" -gt 0 ]; then emit android pass "$tool" "$secs" "$n" /dev/null "$other" "the written files have no errors; other files do"; note pass
  else
    local why; why="$(grep -E "Task '.*' not found|Cannot locate tasks|What went wrong" -A2 "$TMP/gradle.log" | grep -v '^--$' | head -3 | tr '\n' ' ' | cut -c1-240)"
    [ -n "$why" ] || why="$(grep -v '^[[:space:]]*$' "$TMP/gradle.log" | tail -1 | cut -c1-240)"
    emit android not-run "$tool" "$secs" "$n" /dev/null 0 "Gradle stopped before compiling: $why"; note not-run
  fi
}

# ---------------------------------------------------------------- iOS (swiftc -typecheck)
# derived_data <xcodeproj> : the project's DerivedData folder, from BUILD_DIR of its first scheme (Xcode
# derives the folder name from the project path, so this is the folder Xcode itself uses; without a
# scheme, xcodebuild reports the legacy build/ folder instead)
derived_data() {
  local scheme
  scheme="$(xcodebuild -list -json -project "$1" 2>/dev/null | jq -r '.project.schemes[0] // empty' 2>/dev/null)"
  [ -n "$scheme" ] || return 0
  xcodebuild -showBuildSettings -project "$1" -scheme "$scheme" 2>/dev/null \
    | sed -nE 's#^[[:space:]]*BUILD_DIR = (.*)/Build/Products$#\1#p' | head -1
}

# simulator_slices <folder>... : the simulator slice of every xcframework below the folders
simulator_slices() {
  local x s
  find "$@" -name '*.xcframework' -type d -prune 2>/dev/null | while IFS= read -r x; do
    for s in "$x"/ios-*simulator; do [ -d "$s" ] && { printf '%s\n' "$s"; break; }; done
  done
}

check_ios() {
  local n=${#ios_files[@]} start=$SECONDS
  command -v xcrun >/dev/null || { emit ios not-run "swiftc -typecheck" 0 "$n" /dev/null 0 "no Xcode command line tools (xcrun)"; note not-run; return; }
  local sdk; sdk="$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)"
  [ -n "$sdk" ] || { emit ios not-run "swiftc -typecheck" 0 "$n" /dev/null 0 "no iOS Simulator SDK in the selected Xcode"; note not-run; return; }
  # the target's Swift files: every .swift file under the top-level folders that hold the written files
  local f top tops=()
  for f in "${ios_files[@]}"; do
    top="$(rel "$f")"; top="${top%%/*}"
    [ -d "$PROJECT/$top" ] || top="."
    printf '%s\n' "${tops[@]:-}" | grep -qxF "$top" || tops+=("$top")
  done
  if printf '%s\n' "${tops[@]}" | grep -qxF "."; then
    emit ios not-run "swiftc -typecheck" 0 "$n" /dev/null 0 "a written Swift file sits at the project root; its target's files are unknown"; note not-run; return
  fi
  local srcs=() t
  for t in "${tops[@]}"; do
    while IFS= read -r s; do srcs+=("$s"); done < <(find "$PROJECT/$t" \( -name Pods -o -name .build -o -name DerivedData -o -name node_modules \
      -o -name "$STATE_DIR" -o -name '*Tests' -o -name '*.xcodeproj' -o -name '*.xcworkspace' \) -prune -o -name '*.swift' -type f -print | sort)
  done
  # resolved binary packages: CocoaPods' Pods/, else the project's DerivedData (resolved now when empty)
  local dirs=() how="" s
  if [ -d "$PROJECT/Pods" ]; then dirs+=("$PROJECT/Pods"); how="Pods"
  elif [ -f "$PROJECT/Podfile" ]; then
    emit ios not-run "swiftc -typecheck" $((SECONDS - start)) "$n" /dev/null 0 "the Podfile's pods are not installed (no Pods/); this check does not run pod install"; note not-run; return
  else
    local xp="" dd rc
    xp="$(find "$PROJECT" -maxdepth 1 -name '*.xcodeproj' -type d | head -1)"
    if [ -z "$xp" ] && [ -f "$PROJECT/project.yml" ]; then
      if command -v xcodegen >/dev/null; then
        # XcodeGen writes the Xcode project under the plugin's state folder, never next to project.yml
        mkdir -p "$PROJECT/$STATE_DIR/typecheck"
        [ -f "$PROJECT/$STATE_DIR/typecheck/.gitignore" ] || printf '*\n' > "$PROJECT/$STATE_DIR/typecheck/.gitignore"
        (cd "$PROJECT" && xcodegen generate --spec project.yml --project "$STATE_DIR/typecheck" --quiet) > "$TMP/xcodegen.log" 2>&1
        xp="$(find "$PROJECT/$STATE_DIR/typecheck" -maxdepth 1 -name '*.xcodeproj' -type d | head -1)"
      fi
      [ -n "$xp" ] || { emit ios not-run "swiftc -typecheck" $((SECONDS - start)) "$n" /dev/null 0 "the project has only project.yml and XcodeGen is not installed, so its Swift packages cannot be resolved"; note not-run; return; }
    fi
    [ -n "$xp" ] || { emit ios not-run "swiftc -typecheck" $((SECONDS - start)) "$n" /dev/null 0 "no Xcode project, project.yml, or Pods/ to resolve the packages from"; note not-run; return; }
    dd="$(derived_data "$xp")"
    [ -n "$dd" ] || { emit ios not-run "swiftc -typecheck" $((SECONDS - start)) "$n" /dev/null 0 "xcodebuild -showBuildSettings gave no BUILD_DIR for $(rel "$xp")"; note not-run; return; }
    how="DerivedData"
    if [ ! -d "$dd/SourcePackages/artifacts" ]; then
      run_limited "$TMP/resolve.log" xcodebuild -resolvePackageDependencies -project "$xp"; rc=$?
      [ -d "$dd/SourcePackages/artifacts" ] || { emit ios not-run "swiftc -typecheck" $((SECONDS - start)) "$n" /dev/null 0 "xcodebuild -resolvePackageDependencies left no binary packages (exit $rc): $(grep -i error "$TMP/resolve.log" | head -1 | cut -c1-200)"; note not-run; return; }
      how="DerivedData, resolved now"
    fi
    dirs+=("$dd/SourcePackages/artifacts")
  fi
  local fw=()
  while IFS= read -r s; do fw+=(-F "$s"); done < <(simulator_slices "${dirs[@]}")
  # deployment target: project.yml `iOS: "15.0"`, else the Xcode project's IPHONEOS_DEPLOYMENT_TARGET
  local dt=""
  [ -f "$PROJECT/project.yml" ] && dt="$(grep -Eo 'iOS:[[:space:]]*"?[0-9]+(\.[0-9]+)?' "$PROJECT/project.yml" | head -1 | grep -Eo '[0-9]+(\.[0-9]+)?')"
  [ -n "$dt" ] || dt="$(grep -hEo 'IPHONEOS_DEPLOYMENT_TARGET = [0-9]+(\.[0-9]+)?' "$PROJECT"/*.xcodeproj/project.pbxproj 2>/dev/null | head -1 | grep -Eo '[0-9]+(\.[0-9]+)?$')"
  [ -n "$dt" ] || dt="15.0"
  local arch; arch="$(uname -m)"; [ "$arch" = arm64 ] || arch=x86_64
  local tool="swiftc -typecheck (${#srcs[@]} files, packages: $how)" rc
  run_limited "$TMP/swiftc.log" xcrun --sdk iphonesimulator swiftc -typecheck -sdk "$sdk" -target "$arch-apple-ios$dt-simulator" \
    -module-name App "${fw[@]}" "${srcs[@]}"; rc=$?
  local secs=$((SECONDS - start))
  if [ "$rc" = 124 ]; then emit ios not-run "$tool" "$secs" "$n" /dev/null 0 "stopped after ${LIMIT} s"; note not-run; return; fi
  local missing; missing="$(grep -Eo "error: no such module '[^']+'" "$TMP/swiftc.log" | head -1 | sed -E "s/.*'(.*)'/\1/")"
  if [ -n "$missing" ]; then
    emit ios not-run "$tool" "$secs" "$n" /dev/null 0 "module $missing is not a resolved binary package; only a build can provide it"; note not-run; return
  fi
  sed -nE 's#^(/[^:]+\.swift):([0-9]+):([0-9]+): error: (.*)$#\1\t\2\t\3\t\4#p' "$TMP/swiftc.log" | sort -u | while IFS=$'\t' read -r p l c m; do
    printf '%s\t%s\t%s\t%s\n' "$(rel "$p")" "$l" "$c" "$m"
  done > "$TMP/ios.all"
  for f in "${ios_files[@]}"; do rel "$f"; echo; done > "$TMP/ios.mine.list"
  local other; other="$(split_errors "$TMP/ios.all" "$TMP/ios.mine.list" "$TMP/ios.mine")"
  if [ -s "$TMP/ios.mine" ]; then emit ios fail "$tool" "$secs" "$n" "$TMP/ios.mine" "$other" ""; note fail
  elif [ "$rc" = 0 ]; then emit ios pass "$tool" "$secs" "$n" /dev/null 0 ""; note pass
  elif [ "$other" -gt 0 ]; then emit ios pass "$tool" "$secs" "$n" /dev/null "$other" "the written files have no errors; other files do"; note pass
  else emit ios not-run "$tool" "$secs" "$n" /dev/null 0 "swiftc stopped without an error in the project: $(grep 'error:' "$TMP/swiftc.log" | head -1 | cut -c1-200)"; note not-run
  fi
}

[ ${#js_files[@]} -gt 0 ] && check_js
[ ${#android_files[@]} -gt 0 ] && check_android
[ ${#ios_files[@]} -gt 0 ] && check_ios
if [ ${#js_files[@]} = 0 ] && [ ${#android_files[@]} = 0 ] && [ ${#ios_files[@]} = 0 ]; then
  emit none not-run "" 0 0 /dev/null 0 "no written .ts, .tsx, .kt, .java, or .swift file inside the project"; note not-run
fi
exit "$worst"
