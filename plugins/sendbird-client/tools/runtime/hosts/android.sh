#!/usr/bin/env bash
# Android host driver for tools/runtime/run.sh (android-view, android-compose). Called with the RT_*
# environment run.sh exports. On the working copy (a Gradle Kotlin-DSL app module at app/):
#   1. adds an instrumented test (hosts/android/RTRuntimeTest.kt.tmpl) and its test-only
#      dependencies; the test runs in the app's process and signs in through the app's LoginService
#   2. gives the App ID the way the build reads it: environment variables and Gradle properties
#      (ORG_GRADLE_PROJECT_<name>) for the Gradle run
#   3. builds both APKs, starts its own read-only emulator (RT_AVD, default the first AVD
#      `emulator -list-avds` names; or uses RT_ANDROID_SERIAL), installs, runs the test, and in parallel drives user B with the Node peer
# With RT_RN=1 (hosts/react-native.sh) the Gradle project is a React Native app's android/ folder
# (Groovy or Kotlin DSL): the same test, built against the release build (JavaScript bundled in, no
# Metro), for the device's ABI only. The test does not sign in itself: the harness entry in the
# app's JavaScript does, or the test signs in through the app's own form.
# Exit 0 = driver finished (steps.jsonl says pass/fail), 1 = failed, 2 = skipped (prints SKIP: ...).
set -uo pipefail
ROOT="$(cd "$RT_HERE/../.." && pwd)"
HERE="$RT_HERE/hosts/android"
work="$RT_WORK"; out="$RT_OUT"; tools="$RT_TOOLS"
step() { jq -nc --arg s "$1" --argjson ok "$2" --arg d "$3" '{step:$s, ok:$ok, detail:$d, screenshot:null}' >> "$out/steps.jsonl"; echo "step $1: $([ "$2" = true ] && echo ok || { [ "$2" = null ] && echo n/a || echo FAIL; }) — $3"; }
peer() { ( cd "$tools" && node peer.mjs "$@" ); }
# after B missed A's text in channel $1: why, when A's own view has it (peer.mjs HIDDEN_NOTE)
hidden_note() { [ -n "$1" ] && peer sender-only "$RT_USER_A" "$1" "$2" 2>/dev/null | jq -r 'select(.ok) | .note' 2>/dev/null; }

# React Native (RT_RN=1, hosts/react-native.sh): the Gradle project is the app's android/ folder
rn="${RT_RN:-0}"; adir="$work"; [ "$rn" = 1 ] && adir="$work/android"
eval "$(bash "$ROOT/tools/local-sdk/android-toolchain.sh" "$adir")"
[ -n "${ANDROID_HOME:-}" ] && [ -n "${JAVA_HOME:-}" ] || { echo "SKIP: no JDK 17 or Android SDK found (tools/local-sdk/android-toolchain.sh)"; exit 2; }
adb="$ANDROID_HOME/platform-tools/adb"; emu="$ANDROID_HOME/emulator/emulator"
gradle_file="$work/app/build.gradle.kts"
if [ "$rn" = 1 ]; then
  gradle_file="$adir/app/build.gradle"; [ -f "$gradle_file" ] || gradle_file="$adir/app/build.gradle.kts"
  [ -f "$gradle_file" ] || { step launch false "no android/app/build.gradle in the React Native project"; exit 1; }
fi
[ -f "$gradle_file" ] || { step launch false "no app/build.gradle.kts: the Android driver handles Kotlin-DSL app modules only"; exit 1; }

# --- harness test ------------------------------------------------------------------------------
# applicationId = "x" (Kotlin DSL) or applicationId "x" (Groovy, the React Native template)
app_id="$(grep -Eo 'applicationId *=? *"[^"]+"' "$gradle_file" | head -1 | sed -E 's/.*"([^"]+)"/\1/')"
if [ "$rn" = 1 ]; then
[ -n "$app_id" ] || { step launch false "no applicationId in ${gradle_file#"$work"/}"; exit 1; }
# the sign-in hook is in the app's JavaScript entry; the test only records that it is there
call="${RT_RN_SIGNIN_TEXT:-none, the app signs in through its own form}"
mkdir -p "$adir/app/src/androidTest/java/rt/harness"
sed -e "s|/\*RT_IMPORT\*/||" -e "s|/\*RT_CALL\*/|/* the harness entry in the app's JavaScript signs in */|" -e "s|/\*RT_CALL_TEXT\*/|$call|" \
  "$HERE/RTRuntimeTest.kt.tmpl" > "$adir/app/src/androidTest/java/rt/harness/RTRuntimeTest.kt"
cp "$HERE/RTSignin.kt" "$adir/app/src/androidTest/java/rt/harness/"
# the release build (JavaScript bundled in, no Metro) is the one under test
if [ "${gradle_file##*.}" = kts ]; then
  cat >> "$gradle_file" <<'KTS'

// --- runtime harness (tools/runtime): instrumented test support, added to a copy only ---
android { defaultConfig { testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }; testBuildType = "release" }
dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
KTS
else
  cat >> "$gradle_file" <<'GROOVY'

// --- runtime harness (tools/runtime): instrumented test support, added to a copy only ---
android {
    defaultConfig { testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner" }
    testBuildType "release"
}
dependencies {
    androidTestImplementation "androidx.test:runner:1.6.2"
    androidTestImplementation "androidx.test:core:1.6.1"
    androidTestImplementation "androidx.test.ext:junit:1.2.1"
    androidTestImplementation "androidx.test.uiautomator:uiautomator:2.3.0"
}
GROOVY
fi
else
login_file="$(grep -rl --include='*.kt' 'fun onLoginSucceeded' "$work/app/src/main" 2>/dev/null | head -1)"
[ -n "$app_id" ] && [ -n "$login_file" ] || { step sign-in false "no applicationId or onLoginSucceeded in the app module"; exit 1; }
login_pkg="$(sed -nE 's/^package +([A-Za-z0-9_.]+).*/\1/p' "$login_file" | head -1)"
sig="$(grep -E 'fun onLoginSucceeded' "$login_file" | head -1)"
# the class or object whose body encloses onLoginSucceeded (prints "kind name"): follow brace
# depth, so a nested type declared before the function (data class Failed(...)) is not taken
owner="$(awk '
  { line = $0 }
  line ~ /fun onLoginSucceeded/ { print top; exit }
  match(line, /(class|object) [A-Za-z0-9_]+/) { split(substr(line, RSTART, RLENGTH), a, " "); pend = a[1] " " a[2] }
  { o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line)
    for (i = 0; i < o; i++) { depth++; owner_at[depth] = pend; pend = "" }
    for (i = 0; i < c; i++) { owner_at[depth] = ""; depth-- }
    if (o == 0) pend = ""   # a declaration without a body on its line (data class X(...)) owns nothing
    top = ""; for (i = depth; i >= 1; i--) if (owner_at[i] != "") { top = owner_at[i]; break } }
' "$login_file")"
recv="${owner#* }()"; [ "${owner%% *}" = object ] && recv="${owner#* }"
call="$recv.onLoginSucceeded(userA)"
case "$sig" in *suspend*) call="kotlinx.coroutines.runBlocking { $call }" ;; esac
mkdir -p "$work/app/src/androidTest/java/rt/harness"
sed -e "s|/\*RT_IMPORT\*/|import $login_pkg.${owner#* }|" -e "s|/\*RT_CALL\*/|$call|" -e "s|/\*RT_CALL_TEXT\*/|$recv.onLoginSucceeded(userId)|" \
  "$HERE/RTRuntimeTest.kt.tmpl" > "$work/app/src/androidTest/java/rt/harness/RTRuntimeTest.kt"
cp "$HERE/RTSignin.kt" "$work/app/src/androidTest/java/rt/harness/"
cat >> "$gradle_file" <<'KTS'

// --- runtime harness (tools/runtime): instrumented test support, added to a copy only ---
android { defaultConfig { testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" } }
dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
KTS
fi

# --- build ---------------------------------------------------------------------------------------
genv=()
for n in $RT_ENV_NAMES; do genv+=("$n=$RT_APP_ID"); done
for n in $RT_GRADLE_PROPS; do genv+=("ORG_GRADLE_PROJECT_$n=$RT_APP_ID"); done
# the project's own Gradle wrapper first; RT_GRADLEW (the tests' wrapper for the e2e fixtures, which have none)
if [ -x "$adir/gradlew" ]; then gradlew="$adir/gradlew"
elif [ -n "${RT_GRADLEW:-}" ] && [ -x "$RT_GRADLEW" ]; then gradlew="$RT_GRADLEW"
elif command -v gradle >/dev/null; then gradlew=gradle
else echo "SKIP: no Gradle wrapper (gradlew) in the project and no gradle on PATH"; exit 2; fi
variant=debug; tasks=(:app:assembleDebug :app:assembleDebugAndroidTest)
if [ "$rn" = 1 ]; then
  variant=release; tasks=(:app:assembleRelease :app:assembleReleaseAndroidTest)
  # React Native compiles native code for every ABI it lists (reactNativeArchitectures); build only
  # the one of the device the run uses: the running device's, or the AVD's from its config.ini
  if [ -n "${RT_ANDROID_SERIAL:-}" ]; then abi="$("$adb" -s "$RT_ANDROID_SERIAL" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
  else
    avd_name="${RT_AVD:-$("$emu" -list-avds 2>/dev/null | head -1)}"
    avd_dir="$(sed -n 's/^path=//p' "$HOME/.android/avd/$avd_name.ini" 2>/dev/null)"
    abi="$(sed -n 's/^abi\.type *= *//p' "${avd_dir:-$HOME/.android/avd/$avd_name.avd}/config.ini" 2>/dev/null | head -1)"
  fi
  [ -n "${abi:-}" ] && tasks+=("-PreactNativeArchitectures=$abi")
fi
echo "building $app_id ($variant; sign-in hook: $call)"
if ! env ${genv[@]+"${genv[@]}"} "$gradlew" -p "$adir" --no-daemon -q "${tasks[@]}" \
     > "$out/gradle.log.raw" 2>&1; then
  step launch false "build failed: $(grep -E '^e: |What went wrong' -A1 "$out/gradle.log.raw" | head -2 | tr '\n' ' ' | cut -c1-200)"
  exit 1
fi
apk="$(ls "$adir"/app/build/outputs/apk/$variant/*.apk | head -1)"
tapk="$(ls "$adir"/app/build/outputs/apk/androidTest/$variant/*.apk | head -1)"

# --- device --------------------------------------------------------------------------------------
serial="${RT_ANDROID_SERIAL:-}"; emu_pid=""
if [ -z "$serial" ]; then
  [ -x "$emu" ] || { echo "SKIP: no emulator in $ANDROID_HOME"; exit 2; }
  avd="${RT_AVD:-$("$emu" -list-avds 2>/dev/null | head -1)}"
  [ -n "$avd" ] || { echo "SKIP: no Android Virtual Device (set RT_AVD or RT_ANDROID_SERIAL)"; exit 2; }
  port=5600; while "$adb" devices | grep -q "emulator-$port"; do port=$((port+2)); done
  serial="emulator-$port"
  # -read-only: another instance of the same AVD may already be running; nothing is saved
  "$emu" -avd "$avd" -port "$port" -read-only -no-window -no-audio -no-boot-anim -no-snapshot > "$out/emulator.log" 2>&1 &
  emu_pid=$!
fi
cleanup() { [ -n "$emu_pid" ] && { "$adb" -s "$serial" emu kill >/dev/null 2>&1; sleep 2; kill "$emu_pid" 2>/dev/null; }; }
trap cleanup EXIT
# `adb wait-for-device` alone waits forever: an emulator that cannot start its AVD (for example
# "Broken AVD system path" when ANDROID_HOME is an SDK without the AVD's system image) exits at
# once, and an RT_ANDROID_SERIAL that names no device never appears.
for _ in $(seq 1 150); do
  [ "$("$adb" -s "$serial" get-state 2>/dev/null)" = device ] && break
  if [ -n "$emu_pid" ] && ! kill -0 "$emu_pid" 2>/dev/null; then
    step launch false "the emulator for $avd exited before $serial came up: $(grep -m1 -E 'FATAL|ERROR' "$out/emulator.log" | cut -c1-200)"
    exit 1
  fi
  sleep 2
done
[ "$("$adb" -s "$serial" get-state 2>/dev/null)" = device ] || { step launch false "device $serial did not come up within 300 seconds"; exit 1; }
for _ in $(seq 1 180); do [ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break; sleep 2; done
[ "$("$adb" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] || { step launch false "emulator $serial did not boot"; exit 1; }
# a cold-booted emulator keeps starting system apps for a while; an app launched right away can
# hit "isn't responding" before its own code runs
[ -n "$emu_pid" ] && sleep 30
"$adb" -s "$serial" shell settings put global window_animation_scale 0 >/dev/null 2>&1
"$adb" -s "$serial" shell settings put global transition_animation_scale 0 >/dev/null 2>&1
"$adb" -s "$serial" shell settings put global animator_duration_scale 0 >/dev/null 2>&1
"$adb" -s "$serial" install -r -g "$apk" > "$out/install.log" 2>&1 && "$adb" -s "$serial" install -r -g "$tapk" >> "$out/install.log" 2>&1 \
  || { step launch false "adb install failed (install.log)"; exit 1; }
rtdir="/sdcard/Android/data/$app_id/files/rt"
"$adb" -s "$serial" shell rm -rf "$rtdir" >/dev/null 2>&1
"$adb" -s "$serial" logcat -c

# --- run: instrumented test (user A) and peer (user B) side by side ---------------------------------
# digits only: a letter tag ("55dck") hit the test app's profanity filter and the server stored
# the whole message as asterisks (2026-10-14)
tag="$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 6)"
channel="rt-chan-$tag"; b1="hello A from B $tag"; a1="hello B from A $tag"; b2="still there A $tag"
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }
"$adb" -s "$serial" logcat -v raw -s RTSTEP:I > "$out/rtstep.log" 2>/dev/null &
logcat_pid=$!
"$adb" -s "$serial" logcat -v threadtime '*:E' > "$out/logcat-errors.log.raw" 2>/dev/null &
errlog_pid=$!
# adb joins arguments into one shell line, so an empty value would vanish: pass only non-empty ones
# an app with its own sign-in form is signed in through that form, the way a user does, and the hook
# is left unused (lib/signin-form.sh says how a form is recognized)
if [ "$rn" = 1 ]; then signin_form="$RT_RN_SIGNIN_FORM"; else signin_form="$(bash "$RT_HERE/lib/signin-form.sh" android "$work/app/src/main")"; fi
iargs=(-e rtUserA "$RT_USER_A" -e rtTag "$tag" -e rtChatUI "$RT_CHAT_UI" -e rtSigninForm "$signin_form" -e rtDirect "$RT_DIRECT" -e rtRich "$RT_RICH")
if [ "$RT_RICH" = 1 ]; then
  . "$RT_HERE/lib/rich.sh"
  rich_texts "$tag"
  # a photo on the device for the attachment step, indexed so pickers list it
  rich_image "$work/rt-image.png"
  "$adb" -s "$serial" push "$work/rt-image.png" "/sdcard/Pictures/rt-image-$tag.png" >/dev/null 2>&1 \
    && "$adb" -s "$serial" shell content call --uri content://media/external/file --method scan_volume --arg external_primary >/dev/null 2>&1 \
    || step rich-setup false "could not put a photo on the device"
fi
[ -n "$RT_EXPECT_TEXT" ] && iargs+=(-e rtExpectText "$(b64 "$RT_EXPECT_TEXT")")
[ -n "$RT_EXPECT_SELECTOR" ] && iargs+=(-e rtExpectElement "$(b64 "$RT_EXPECT_SELECTOR")")
{ [ "$RT_DIRECT" = 1 ] && peer touch "$RT_USER_B" >/dev/null; }
"$adb" -s "$serial" shell am instrument -w -r "${iargs[@]}" \
  -e class rt.harness.RTRuntimeTest "$app_id.test/androidx.test.runner.AndroidJUnitRunner" > "$out/instrument.log.raw" 2>&1 &
test_pid=$!

signal() { "$adb" -s "$serial" shell "mkdir -p $rtdir && touch $rtdir/$1" >/dev/null 2>&1; }
if pres="$(peer presence "$RT_USER_A" online 180)"; then
  step connect true "server reports $RT_USER_A online"
  if [ "$RT_CHAT_UI" = 1 ] && kill -0 "$test_pid" 2>/dev/null; then
    if [ "$RT_DIRECT" = 1 ]; then
      found="$(peer find-expect "$RT_USER_B" "$RT_USER_A" "$a1" 240)"
      url="$(jq -r '.channelUrl // empty' <<<"$found")"
      if jq -e '.ok' <<<"$found" >/dev/null; then
        step message-a-sends true "$RT_USER_B received A's \"$a1\" in the 1:1 channel the app opened"
        peer send "$RT_USER_B" "$url" "$b2" >/dev/null || step message-b-sends false "peer could not send the reply"
      else
        step message-a-sends false "$RT_USER_B never received \"$a1\": $(jq -r '.error // "no matching message"' <<<"$found")$(hidden_note "$url" "$a1")"; signal abort
      fi
    else
      seeded="$(peer seed "$RT_USER_B" "$RT_USER_A" "$channel" "$b1" ${RT_B_CUSTOM_TYPE:+"$RT_B_CUSTOM_TYPE"})"
      url="$(jq -r '.channelUrl // empty' <<<"$seeded")"
      if [ -n "$url" ]; then
        if peer expect "$RT_USER_B" "$url" "$RT_USER_A" "$a1" 240 >/dev/null; then
          step message-a-sends true "server has A's \"$a1\""
          peer send "$RT_USER_B" "$url" "$b2" >/dev/null || step message-b-sends false "peer could not send the live message"
          rich_url="$url"
          [ "$RT_RICH" = 1 ] && rich_wait_a2 "$url" && { a2_sent=1; signal a2-seen; }
          [ "$RT_RICH" = 1 ] && kill -0 "$test_pid" 2>/dev/null && rich_wait_file "$url"; signal file-seen
        else
          step message-a-sends false "B never received \"$a1\"$(hidden_note "$url" "$a1")"; signal abort
        fi
      else
        step channel-seed false "peer could not open a channel: $(jq -r '.error // "?"' <<<"$seeded")"; signal abort
      fi
    fi
  fi
else
  step connect false "$(jq -r --arg u "$RT_USER_A" '.error // "server reports \($u) \(.status // "unknown") after 180s"' <<<"$pres")"; signal abort
fi
signal release
wait "$test_pid"
sleep 1; kill "$logcat_pid" "$errlog_pid" 2>/dev/null
# steps the test logged, then screenshots and window dumps it saved
grep -E '^\{' "$out/rtstep.log" >> "$out/steps.jsonl"
[ "$RT_RICH" = 1 ] && [ -n "${rich_url:-}" ] && rich_server "$rich_url" "$b1" "$a1" "${a2_sent:-0}"
mkdir -p "$out/screens"
"$adb" -s "$serial" pull "$rtdir" "$out/android-rt" >/dev/null 2>&1
find "$out/android-rt" -name '*.png' -exec mv {} "$out/screens/" \; 2>/dev/null
find "$out/android-rt" -name '*.xml' -exec mv {} "$out/" \; 2>/dev/null
rm -rf "$out/android-rt"
if grep -q "FATAL EXCEPTION" "$out/logcat-errors.log.raw"; then
  step no-crash false "the app crashed: $(grep -A2 'FATAL EXCEPTION' "$out/logcat-errors.log.raw" | tail -1 | sed -E 's/^.*AndroidRuntime: //' | cut -c1-200)"
fi
if ! grep -q "OK (1 test)" "$out/instrument.log.raw" && ! grep -q '"ok":false' "$out/steps.jsonl"; then
  step ui-test false "instrumented test failed: $(grep -m1 -E 'shortMsg|Error|Exception' "$out/instrument.log.raw" | cut -c1-200)"
fi
exit 0
