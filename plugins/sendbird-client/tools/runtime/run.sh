#!/usr/bin/env bash
# Run a Sendbird app project for real and check that it works against a Sendbird application:
# it starts, signs in user A, connects, and (when it has Sendbird UIKit screens, or --chat-screens)
# opens a channel that user B starts, shows B's message, and sends one back that B receives.
# Used by the run-check skill (only after the customer asked for it and agreed to the build) and by
# this repository's tests (tests/runtime/run.sh passes --app-id-env SENDBIRD_TEST_APP_ID).
#
# Usage: run.sh <project-dir> --host <react|react-native|ios-uikit|ios-swiftui|android-view|android-compose>
#               [--platform ios|android] [--check] [--out DIR] [--app-id-env NAME] [--expect-text TEXT]...
#               [--expect-element ID]... [--b-custom-type TYPE] [--direct-chat USER] [--chat-screens] [--rich] [--keep]
#   --platform        react-native only, and required there: run the app's ios/ project on an iOS
#                     simulator or its android/ project on an Android emulator, one platform per run.
#                     The app is a release build with its JavaScript bundled in, so no Metro server
#                     runs (hosts/react-native.sh)
#   --rich            after the two-way exchange, drive the conversation features one by one: a
#                     reaction on B's message, edit and delete of A's own messages, an image
#                     attachment, and a message search; user B checks each on the server (lib/rich.sh).
#                     Not supported for --host react-native (exit 64)
#   --check           preflight only: report what the run needs and what is missing (JSON on stdout).
#                     Copies, installs, builds, and launches nothing. Exit 0 ready, 2 not ready.
#   --app-id-env      read the App ID from this environment variable only. Default: SENDBIRD_APP_ID,
#                     then appId in the project's .sendbird-client/profile.json
#   --chat-screens    the app has its own chat screens built on the Chat SDK (no UIKit dependency):
#                     drive them like UIKit screens instead of stopping after connect. Not decided
#                     automatically: the harness finds screens by their controls (a chat or channel
#                     button, the channel's row, a message input), and code that sends a message
#                     does not show that a screen with those controls exists. Without UIKit and
#                     without this flag, the channel and message steps are recorded as not run, and
#                     runtime.json messageSteps and the last lines of the output say so and name this
#                     flag (with the file whose Chat SDK code sends messages, when there is one)
#   --direct-chat     the app opens a 1:1 chat with USER from a button (no channel list): user B
#                     is USER, A taps the button (on a product screen one tap away, if need be), the
#                     conversation must open by itself, A sends, B finds A's message in the channel
#                     the app made, and A must see B's reply. Every host, React Native included. It
#                     says the app has a chat screen, so it needs neither UIKit nor --chat-screens
#   --b-custom-type   customType on user B's first message, for a customization that renders
#                     such messages differently (the marker is then checked with --expect-*)
#   --expect-text     text that must be on the chat screen (a customization), repeatable
#   --expect-element  element that must be on the chat screen: a CSS selector (react), an
#                     accessibility identifier (iOS), or a resource id / content description (Android)
#   --keep            keep the working copy (it holds the App ID; delete it yourself)
#
# The application must allow connecting with a user ID only: users A and B are new test users with
# generated IDs (rt-<host>-a-xxxxxx) and no access token. Without an App ID the run is skipped:
# prints "SKIP: ..." and exits 2. Exit codes: 0 pass, 1 fail, 2 skip, 64 bad arguments.
# The project directory is never modified: the harness works on a copy, gives it the App ID the
# way the project reads it (lib/appid.py), and adds only harness files to the copy.
# Writes <out>/runtime.json ({status: pass|fail|skip, reason, steps[]}), steps.jsonl, screens/*.png,
# and logs with the App ID removed (lib/redact.py). The App ID is never printed: the host driver's
# output and the result lines pass through lib/redact.py before they reach the terminal.
#
# Environment: RUNTIME_TOOLS_DIR (default $TMPDIR/sendbird-runtime-tools) holds the pinned npm
# tools (Playwright, Vite, @sendbird/chat for user B) and Chromium; nothing is installed into the
# project. RT_SIMULATOR (iOS device type, default "iPhone 17 Pro"), RT_AVD (Android
# AVD, default the first one `emulator -list-avds` names) or RT_ANDROID_SERIAL (a running device).
# RT_GRADLEW: a Gradle wrapper for an Android project that has none of its own.
set -uo pipefail
# Until it is marked shown, the first-run notice (hooks/first-run-notice.sh) goes to stderr: in Codex a
# skill can run this before the plugin's hooks are trusted.
first_run_notice="$(cd "$(dirname "$0")" && pwd)/../../hooks/first-run-notice.sh"
[ ! -f "$first_run_notice" ] || bash "$first_run_notice" script || true
HERE="$(cd "$(dirname "$0")" && pwd)"
usage() { echo "usage: run.sh <project-dir> --host <react|react-native|ios-uikit|ios-swiftui|android-view|android-compose> [--platform ios|android] [--check] [--out DIR] [--app-id-env NAME] [--expect-text TEXT]... [--expect-element ID]... [--b-custom-type TYPE] [--direct-chat USER] [--chat-screens] [--rich] [--keep]" >&2; exit 64; }

project=""; host=""; platform=""; out=""; keep=0; check=0; app_id_env=""; expect_text=""; expect_element=""; b_custom_type=""; direct_user=""; chat_screens=0; rich=0
while [ $# -gt 0 ]; do
  case "$1" in
    --host) [ $# -ge 2 ] || usage; host="$2"; shift 2 ;;
    --platform) [ $# -ge 2 ] || usage; platform="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || usage; out="$2"; shift 2 ;;
    --app-id-env) [ $# -ge 2 ] || usage; app_id_env="$2"; shift 2 ;;
    --expect-text) [ $# -ge 2 ] || usage; expect_text="${expect_text}${2}"$'\n'; shift 2 ;;
    --expect-element) [ $# -ge 2 ] || usage; expect_element="${expect_element}${2}"$'\n'; shift 2 ;;
    --b-custom-type) [ $# -ge 2 ] || usage; b_custom_type="$2"; shift 2 ;;
    --direct-chat) [ $# -ge 2 ] || usage; direct_user="$2"; shift 2 ;;
    --chat-screens) chat_screens=1; shift ;;
    --rich) rich=1; shift ;;
    --check) check=1; shift ;;
    --keep) keep=1; shift ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) [ -z "$project" ] || { echo "more than one project dir: $1" >&2; usage; }; project="$1"; shift ;;
  esac
done
[ -n "$project" ] || usage
[ -d "$project" ] || { echo "not a directory: $project" >&2; exit 64; }
case "$host" in
  react|react-native|ios-uikit|ios-swiftui|android-view|android-compose) ;;
  "") echo "--host is required" >&2; usage ;;
  *) echo "unknown host: $host" >&2; usage ;;
esac
# A React Native app runs on one platform per run; every other host has its platform already.
if [ "$host" = react-native ]; then
  case "$platform" in
    ios|android) ;;
    "") echo "--host react-native needs --platform ios or --platform android" >&2; exit 64 ;;
    *) echo "unknown --platform: $platform (ios or android)" >&2; exit 64 ;;
  esac
  # --rich has not been run on React Native screens: refuse instead of running an unchecked scenario
  [ "$rich" = 0 ] || { echo "--rich is not supported for --host react-native (only ios-uikit, ios-swiftui, android-view, android-compose)" >&2; exit 64; }
elif [ -n "$platform" ]; then
  echo "--platform applies to --host react-native only" >&2; exit 64
fi
[[ -z "$app_id_env" || "$app_id_env" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "bad --app-id-env name: $app_id_env" >&2; usage; }
# user B signs in as this ID, and the drivers pass it on (a JavaScript string, an adb argument)
[[ -z "$direct_user" || "$direct_user" =~ ^[A-Za-z0-9_.@-]+$ ]] || { echo "bad --direct-chat user ID: $direct_user (letters, digits, and _ . @ - only)" >&2; exit 64; }
project="$(cd "$project" && pwd)"
TOOLS_DIR="${RUNTIME_TOOLS_DIR:-${TMPDIR:-/tmp}/sendbird-runtime-tools}"

# --- App ID: the run prints where it came from, never the value ---------------------------------
# All zeros, YOUR_..., REPLACE..., <...>: the placeholder a generated config or a test run carries.
is_placeholder() { [[ -z "$1" || "$1" =~ ^0{8}-0{4}-0{4}-0{4}-0{12}$ || "$1" =~ ^(YOUR|REPLACE|\<) ]]; }
profile="$project/.sendbird-client/profile.json"
if [ -n "$app_id_env" ]; then
  RT_APP_ID="${!app_id_env:-}"; app_id_from="$app_id_env"; app_id_missing="$app_id_env is not set"
elif ! is_placeholder "${SENDBIRD_APP_ID:-}"; then
  RT_APP_ID="$SENDBIRD_APP_ID"; app_id_from="SENDBIRD_APP_ID"; app_id_missing=""
else
  RT_APP_ID="$(jq -r '.appId // empty' "$profile" 2>/dev/null || true)"; app_id_from="profile.json appId"
  app_id_missing="no App ID: SENDBIRD_APP_ID is not set (or holds a placeholder) and the project's profile.json has no appId"
fi
is_placeholder "$RT_APP_ID" && RT_APP_ID=""
export RT_APP_ID

# chat_sdk_send <dir>: the first app source file (relative) that sends a message with the Chat SDK.
# Dependency, build, and hidden folders (the plugin's SDK cache among them) and .d.ts files are skipped.
# (source: knowledge/curated/ios/products/chat.md) (source: knowledge/curated/android/products/chat.md)
# (source: knowledge/curated/js/products/chat.md) — channel.sendUserMessage on each platform
chat_sdk_send() {
  local f
  f="$(find "$1" -mindepth 1 \( -name node_modules -o -name build -o -name Pods -o -name DerivedData -o -name dist -o -name '.*' \) -prune \
    -o -type f \( -name '*.swift' -o -name '*.kt' -o -name '*.java' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) ! -name '*.d.ts' -print 2>/dev/null \
    | while IFS= read -r p; do grep -qE '\.sendUserMessage[[:space:]]*\(' "$p" && { echo "$p"; break; }; done)"
  [ -n "$f" ] && echo "${f#"$1"/}"
}
# message_steps_note <chat-ui 0|1> <file from chat_sdk_send>: empty when the message steps run
message_steps_note() {
  [ "$1" = 1 ] && return 0
  echo "the channel and message steps are not run: the app has no Sendbird UIKit dependency${2:+ (its Chat SDK code sends messages in $2)}. If it has its own chat screens, add --chat-screens to drive them"
}

# --- preflight: what a run needs, without copying, installing, building, or launching -----------
# Package names: (source: knowledge/curated/ios/setup.md) (source: knowledge/curated/ios/hosts/swiftui.md)
preflight() {
  local missing=() notes=() signin="" chat_ui=0 how f
  [ -n "$RT_APP_ID" ] || missing+=("$app_id_missing")
  for t in node npm jq python3; do command -v "$t" >/dev/null || missing+=("$t not found"); done
  how="$(python3 -I "$HERE/lib/appid.py" detect "$project" 2>/dev/null | jq -r '.how | join(", ")' 2>/dev/null)"
  [ -n "$how" ] || missing+=("the project reads no App ID the harness can find (no env var, build setting, Gradle property, or config value)")
  case "$host" in
    react)
      if [ -f "$project/index.html" ]; then
        # the user ID input the react driver looks for (USER_FIELD in hosts/react.mjs)
        if grep -rqsE 'id="user"|sb_login_user_id|auto[cC]omplete="username"' "$project/src"; then signin="the app's sign-in form (user ID input)"
        else missing+=("index.html without a sign-in form the harness can fill (a user ID input with id=\"user\" or autocomplete=\"username\", and the button that submits it)"); fi
      else
        f="$(grep -rlE 'export[[:space:]]+(async[[:space:]]+)?function[[:space:]]+onLoginSucceeded\b|export[[:space:]]+const[[:space:]]+onLoginSucceeded\b' "$project/src" 2>/dev/null | head -1)"
        if [ -n "$f" ]; then signin="onLoginSucceeded in ${f#"$project"/}"
        else missing+=("no exported onLoginSucceeded(userId) in src/ for the harness to sign in with"); fi
      fi
      grep -Eqs '"@sendbird/uikit-react"' "$project/package.json" && chat_ui=1
      notes+=("installs pinned tools into $TOOLS_DIR (outside the project): playwright with chromium, vite, @sendbird/chat for user B")
      notes+=("copies the project to a temporary folder, runs npm install there, and serves it with vite") ;;
    react-native)
      grep -Eqs '"react-native"[[:space:]]*:' "$project/package.json" || missing+=("package.json does not list react-native")
      bash "$HERE/lib/rn-app.sh" entry "$project" >/dev/null \
        || missing+=("no index.js (or index.ts, index.tsx, index.jsx) at the project root: the entry a release build bundles")
      # the app's own sign-in form first, as on iOS and Android; else the harness calls onLoginSucceeded
      if [ "$(bash "$HERE/lib/signin-form.sh" rn "$project")" = 1 ]; then signin="the app's sign-in form (a TextInput)"
      elif f="$(bash "$HERE/lib/rn-app.sh" login "$project")"; then signin="onLoginSucceeded in $f"
      else missing+=("no sign-in form and no exported onLoginSucceeded(userId) for the harness to sign in with"); fi
      grep -Eqs '"@sendbird/uikit-react-native"' "$project/package.json" && chat_ui=1
      notes+=("installs pinned tools into $TOOLS_DIR (outside the project): @sendbird/chat for user B")
      if [ "$platform" = ios ]; then
        for t in pod xcodegen xcodebuild xcrun; do command -v "$t" >/dev/null || missing+=("$t not found"); done
        compgen -G "$project/ios/*.xcodeproj" >/dev/null || missing+=("no ios/*.xcodeproj: the app's iOS project")
        [ -f "$project/ios/Podfile" ] || missing+=("no ios/Podfile: React Native's iOS dependencies are installed with CocoaPods")
        notes+=("copies the project to a temporary folder and runs npm install and pod install there")
        notes+=("builds the app's ios/ project in the Release configuration (JavaScript bundled in, no Metro) and a separate UI test project, on a simulator created for this run and deleted afterwards")
      else
        eval "$(bash "$HERE/../local-sdk/android-toolchain.sh" "$project/android" 2>/dev/null)"
        [ -n "${ANDROID_HOME:-}" ] && [ -n "${JAVA_HOME:-}" ] || missing+=("no JDK 17 or Android SDK found (tools/local-sdk/android-toolchain.sh)")
        [ -f "$project/android/app/build.gradle" ] || [ -f "$project/android/app/build.gradle.kts" ] || missing+=("no android/app/build.gradle: the app's Android project")
        [ -x "$project/android/gradlew" ] || command -v gradle >/dev/null || missing+=("no Gradle wrapper (android/gradlew) and no gradle on PATH")
        notes+=("copies the project to a temporary folder and runs npm install there")
        notes+=("builds the app's android/ project as a release build (JavaScript bundled in, no Metro; signed the way its build.gradle signs release builds) with an instrumented test; starts a read-only emulator of RT_AVD, or uses RT_ANDROID_SERIAL")
      fi ;;
    ios-uikit|ios-swiftui)
      for t in xcodegen xcodebuild xcrun; do command -v "$t" >/dev/null || missing+=("$t not found"); done
      [ -f "$project/project.yml" ] || missing+=("no project.yml: the iOS harness builds XcodeGen projects only")
      f="$(grep -rl --include='*.swift' 'func onLoginSucceeded' "$project/Sources" 2>/dev/null | head -1)"
      if [ -n "$f" ]; then signin="onLoginSucceeded in ${f#"$project"/}"
      else missing+=("no onLoginSucceeded in Sources/ for the harness to sign in with"); fi
      grep -Eqs 'sendbird-uikit-ios|sendbird-swiftui-ios|SendbirdUIKit|SendbirdSwiftUI' "$project/project.yml" && chat_ui=1
      notes+=("installs pinned tools into $TOOLS_DIR (outside the project): @sendbird/chat for user B")
      notes+=("builds the app and a UI test target in a copy, on a simulator created for this run and deleted afterwards") ;;
    android-view|android-compose)
      eval "$(bash "$HERE/../local-sdk/android-toolchain.sh" "$project" 2>/dev/null)"
      [ -n "${ANDROID_HOME:-}" ] && [ -n "${JAVA_HOME:-}" ] || missing+=("no JDK 17 or Android SDK found (tools/local-sdk/android-toolchain.sh)")
      [ -f "$project/app/build.gradle.kts" ] || missing+=("no app/build.gradle.kts: the Android harness handles Kotlin-DSL app modules only")
      [ -x "$project/gradlew" ] || command -v gradle >/dev/null || { [ -n "${RT_GRADLEW:-}" ] && [ -x "$RT_GRADLEW" ]; } \
        || missing+=("no Gradle wrapper (gradlew) in the project and no gradle on PATH")
      f="$(grep -rl --include='*.kt' 'fun onLoginSucceeded' "$project/app/src/main" 2>/dev/null | head -1)"
      if [ -n "$f" ]; then signin="onLoginSucceeded in ${f#"$project"/}"
      else missing+=("no onLoginSucceeded in app/src/main for the harness to sign in with"); fi
      grep -Eqs 'com\.sendbird\.sdk:uikit' "$project/app/build.gradle.kts" && chat_ui=1
      notes+=("installs pinned tools into $TOOLS_DIR (outside the project): @sendbird/chat for user B")
      notes+=("builds the app and an instrumented test in a copy; starts a read-only emulator of RT_AVD, or uses RT_ANDROID_SERIAL") ;;
  esac
  [ "$chat_screens" = 1 ] && chat_ui=1
  [ -n "$direct_user" ] && chat_ui=1 && notes+=("direct chat: user B is $direct_user, connected once before the run so A's chat button can invite them; A's button must open the 1:1 conversation without a channel list")
  local msg_note; msg_note="$(message_steps_note "$chat_ui" "$([ "$chat_ui" = 1 ] || chat_sdk_send "$project")")"
  [ -z "$msg_note" ] || notes+=("$msg_note")
  jq -n --arg host "$host" --arg platform "$platform" --arg from "$([ -n "$RT_APP_ID" ] && echo "$app_id_from")" --arg how "$how" --arg signin "$signin" \
    --argjson chat "$chat_ui" --arg msgnote "$msg_note" --arg direct "$direct_user" '
    ($ARGS.positional | map(select(startswith("M:")) | ltrimstr("M:"))) as $missing |
    {ready: ($missing | length == 0), host: $host} + (if $platform == "" then {} else {platform: $platform} end) + {
     appId: (if $from == "" then null else {from: $from} end), appIdHow: $how, signIn: $signin,
     checks: (if $direct != "" then ["connect", "channel", "message-a-sends", "message-a-live"]
              elif $chat == 1 then ["connect", "channel", "message-a-receives", "message-a-sends"] else ["connect"] end),
     directChat: (if $direct == "" then null else $direct end),
     messageSteps: (if $msgnote == "" then {run: true} else {run: false, why: $msgnote, enableWith: "--chat-screens"} end),
     missing: $missing,
     notes: ($ARGS.positional | map(select(startswith("N:")) | ltrimstr("N:")))}' \
    --args ${missing[@]+"${missing[@]/#/M:}"} ${notes[@]+"${notes[@]/#/N:}"}
  [ "${#missing[@]}" -eq 0 ]
}
if [ "$check" -eq 1 ]; then
  if preflight; then exit 0; else exit 2; fi
fi

[ -n "$out" ] || out="$(mktemp -d "${TMPDIR:-/tmp}/runtime.XXXXXX")"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
: > "$out/steps.jsonl"

# say: standard output without the App ID (a driver's step detail can quote a Sendbird host name)
say() { python3 -I -u "$HERE/lib/redact.py" -; }

finish() {  # finish <status> <reason> <exit>
  python3 -I "$HERE/lib/redact.py" "$out"
  jq -n --arg status "$1" --arg reason "$2" --arg host "$host" --arg platform "$platform" --arg project "$project" \
    --arg userA "${RT_USER_A:-}" --arg userB "${RT_USER_B:-}" --argjson appid "${appid_json:-null}" \
    --slurpfile steps "$out/steps.jsonl" --arg msgstate "${msg_state:-}" \
    '{status:$status, reason:$reason, host:$host} + (if $platform == "" then {} else {platform:$platform} end) + {project:$project, users:{a:$userA, b:$userB},
      messageSteps:(if $msgstate == "" then null elif $msgstate == "run" then {run:true}
        else {run:false, why:$msgstate, enableWith:"--chat-screens"} end),
      appIdSource:(if $appid then {how:$appid.how, env:$appid.env, buildSettings:$appid.buildSettings,
        gradleProperties:$appid.gradleProperties, replacedIn:($appid.replacedIn // [])} else null end),
      screenshots:"screens/", steps:$steps}' > "$out/runtime.json"
  python3 -I "$HERE/lib/redact.py" "$out"
  {
    echo "runtime: $1${2:+ — $2}"
    case "${msg_state:-}" in ""|run) ;; *) echo "note: $msg_state" ;; esac
    echo "result: $out/runtime.json"
  } | say
  exit "$3"
}

if [ -z "$RT_APP_ID" ]; then
  echo "SKIP: $app_id_missing (an application that allows user-ID-only connect)"
  finish skip "$app_id_missing" 2
fi
[ "$rich" = 1 ] && [ "$host" = react ] && echo "note: --rich is not implemented for react yet; running the basic checks"
command -v node >/dev/null && command -v npm >/dev/null && command -v jq >/dev/null || finish skip "node, npm, and jq are required" 2

# --- tools: pinned, outside the repo and the project ---------------------------------------------
TOOLS="$TOOLS_DIR"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-$TOOLS/browsers}"
mkdir -p "$TOOLS"
if [ ! -f "$TOOLS/.ready-2" ]; then
  echo "installing harness tools into $TOOLS"
  [ -f "$TOOLS/package.json" ] || echo '{"name":"sendbird-runtime-tools","private":true,"type":"module"}' > "$TOOLS/package.json"
  ( cd "$TOOLS" && npm install --no-audit --no-fund --silent @sendbird/chat@4.22.13 playwright@1.48.2 vite@6.4.3 @vitejs/plugin-react@4.3.4 ) \
    > "$out/tools-install.log" 2>&1 || finish fail "could not install harness tools (tools-install.log)" 1
  touch "$TOOLS/.ready-2"
fi
cp "$HERE/lib/peer.mjs" "$HERE/lib/signin.mjs" "$HERE/hosts/react.mjs" "$HERE/hosts/vite.harness.config.mjs" "$TOOLS/"

# --- the working copy ----------------------------------------------------------------------------
# physical path: Vite will not transform modules under a symlinked root (/var -> /private/var on macOS)
work="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/runtime-work.XXXXXX")" && pwd -P)"
cleanup() { if [ "$keep" -eq 1 ]; then echo "kept working copy: $work (contains the test App ID)"; else rm -rf "$work"; fi; }
trap cleanup EXIT
cp -R "$project/." "$work/"
rm -rf "$work/node_modules" "$work/build" "$work/app/build" "$work/.gradle" "$work"/*.xcodeproj "$work/.sendbird-client"
# React Native: what pod install and the native builds leave behind
rm -rf "$work/ios/Pods" "$work/ios/build" "$work/android/build" "$work/android/app/build" "$work/android/.gradle"

if ! appid_json="$(python3 -I "$HERE/lib/appid.py" apply "$work")"; then
  [ -n "$appid_json" ] || appid_json=null
  why="$(jq -r '.error // empty' <<<"$appid_json" 2>/dev/null)"
  finish fail "${why:-the project reads no App ID the harness can find (no env var, build setting, Gradle property, or config value)}" 1
fi
# names only; each host driver passes the value the way the name says
env_names="$(jq -r '.env | join(" ")' <<<"$appid_json")"
build_settings="$(jq -r '.buildSettings | join(" ")' <<<"$appid_json")"
gradle_props="$(jq -r '.gradleProperties | join(" ")' <<<"$appid_json")"

# Sendbird UIKit present = the app has chat screens, so the channel and message steps are required.
# Package names: (source: knowledge/curated/ios/setup.md) (source: knowledge/curated/ios/hosts/swiftui.md)
chat_ui=0
grep -Eqs '"@sendbird/uikit-react(-native)?"' "$work/package.json" && chat_ui=1
grep -Eqs 'sendbird-uikit-ios|sendbird-swiftui-ios|SendbirdUIKit|SendbirdSwiftUI' "$work/project.yml" && chat_ui=1
grep -Eqs 'com\.sendbird\.sdk:uikit' "$work/app/build.gradle.kts" "$work/app/build.gradle" && chat_ui=1
[ "$chat_screens" = 1 ] && chat_ui=1
# --direct-chat says the app opens a conversation from a button: a chat screen to drive
[ -n "$direct_user" ] && chat_ui=1
# runtime.json messageSteps: "run", or why the channel and message steps are not run
msg_state="$(message_steps_note "$chat_ui" "$([ "$chat_ui" = 1 ] || chat_sdk_send "$work")")"; msg_state="${msg_state:-run}"

rand() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 6; }
RT_USER_A="rt-${host}-a-$(rand)"; RT_USER_B="${direct_user:-rt-${host}-b-$(rand)}"; RT_DIRECT="$([ -n "$direct_user" ] && echo 1 || echo 0)"
export RT_DIRECT RT_RICH="$rich"
export RT_USER_A RT_USER_B RT_WORK="$work" RT_OUT="$out" RT_CHAT_UI="$chat_ui" RT_EXPECT_TEXT="$expect_text" RT_EXPECT_SELECTOR="$expect_element" RT_B_CUSTOM_TYPE="$b_custom_type"
export RT_ENV_NAMES="$env_names" RT_BUILD_SETTINGS="$build_settings" RT_GRADLE_PROPS="$gradle_props" RT_TOOLS="$TOOLS" RT_HERE="$HERE" RT_PLATFORM="$platform"
echo "runtime: $host${platform:+ ($platform)} | A=$RT_USER_A B=$RT_USER_B | chat screens: $([ "$chat_ui" = 1 ] && echo yes || echo no) | App ID via $(jq -r '.how | join(", ")' <<<"$appid_json") | out $out"

case "$host" in
  react)
    if ! compgen -G "$PLAYWRIGHT_BROWSERS_PATH/chromium*" >/dev/null; then
      ( cd "$TOOLS" && npx --no-install playwright install chromium ) >> "$out/tools-install.log" 2>&1 || finish fail "could not install Chromium (tools-install.log)" 1
    fi
    ( cd "$work" && npm install --no-audit --no-fund ) > "$out/npm-install.log.raw" 2>&1 || finish fail "npm install failed in the project (npm-install.log)" 1
    ( cd "$TOOLS" && node react.mjs ) 2>&1 | say | tee "$out/driver.log.raw"
    rc="${PIPESTATUS[0]}" ;;
  ios-uikit|ios-swiftui)
    bash "$HERE/hosts/ios.sh" 2>&1 | say | tee "$out/driver.log.raw"; rc="${PIPESTATUS[0]}" ;;
  android-view|android-compose)
    bash "$HERE/hosts/android.sh" 2>&1 | say | tee "$out/driver.log.raw"; rc="${PIPESTATUS[0]}" ;;
  react-native)
    bash "$HERE/hosts/react-native.sh" 2>&1 | say | tee "$out/driver.log.raw"; rc="${PIPESTATUS[0]}" ;;
esac

# Without chat screens the iOS and Android drivers stop after connect and record nothing for the
# channel and message steps; record them as not run (ok null), as the react driver does.
if [ "$chat_ui" = 0 ]; then
  for s in channel message-a-receives message-a-sends; do
    jq -e --arg s "$s" 'select(.step == $s)' "$out/steps.jsonl" >/dev/null 2>&1 \
      || jq -nc --arg s "$s" '{step:$s, ok:null, detail:"not run: no Sendbird UIKit dependency and no --chat-screens", screenshot:null}' >> "$out/steps.jsonl"
  done
fi
[ "$rc" -eq 2 ] && finish skip "$(grep '^SKIP: ' "$out/driver.log.raw" 2>/dev/null | tail -1 | sed 's/^SKIP: //')" 2
first_fail="$(jq -r 'select(.ok == false) | "\(.step): \(.detail)"' "$out/steps.jsonl" | head -1)"
if [ "$rc" -eq 0 ] && [ -z "$first_fail" ]; then finish pass "" 0; fi
finish fail "${first_fail:-host driver exited $rc}" 1
