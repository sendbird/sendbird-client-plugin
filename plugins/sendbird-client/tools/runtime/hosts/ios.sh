#!/usr/bin/env bash
# iOS host driver for tools/runtime/run.sh (ios-uikit, ios-swiftui). Called with the RT_* environment
# run.sh exports. On the working copy (an XcodeGen project.yml app, as the e2e fixtures are):
#   1. adds the harness sign-in hook (hosts/ios/RTHarness*.{swift,m}) under Sources/, and a UI test
#      target (hosts/ios/RTUITests.swift) through a second spec that includes project.yml
#   2. gives the App ID through the build settings the project reads (an xcconfig passed to xcodebuild).
#      It is never put in the app's launch environment: an app opened from the home screen has none, so
#      an app that reads the App ID only from the environment fails here as it would for its users
#   3. builds for a simulator it creates for this run (deleted afterwards), runs the UI test, and in
#      parallel uses the Node peer as user B: waits for A's presence, opens a channel with A,
#      checks A's reply on the server, then sends one more message for A to see live
# Exit 0 = driver finished (steps.jsonl says pass/fail), 1 = failed, 2 = skipped (prints SKIP: ...).
set -uo pipefail
HERE="$RT_HERE/hosts/ios"
work="$RT_WORK"; out="$RT_OUT"; tools="$RT_TOOLS"
step() { jq -nc --arg s "$1" --argjson ok "$2" --arg d "$3" '{step:$s, ok:$ok, detail:$d, screenshot:null}' >> "$out/steps.jsonl"; echo "step $1: $([ "$2" = true ] && echo ok || { [ "$2" = null ] && echo n/a || echo FAIL; }) — $3"; }
peer() { ( cd "$tools" && node peer.mjs "$@" ); }

for t in xcodegen xcodebuild xcrun; do command -v "$t" >/dev/null || { echo "SKIP: $t not found"; exit 2; }; done
[ -f "$work/project.yml" ] || { step launch false "no project.yml: the iOS driver builds XcodeGen projects only"; exit 1; }

# --- harness files -----------------------------------------------------------------------------
app_target="$(awk '/^targets:/{t=1; next} t && /^  [A-Za-z0-9_]+:/{sub(/^  /,""); sub(/:.*/,""); print; exit}' "$work/project.yml")"
[ -n "$app_target" ] || { step launch false "could not find the app target in project.yml"; exit 1; }
login_file="$(grep -rl --include='*.swift' 'func onLoginSucceeded' "$work/Sources" 2>/dev/null | head -1)"
[ -n "$login_file" ] || { step sign-in false "no onLoginSucceeded in Sources/"; exit 1; }
sig="$(grep -E 'func onLoginSucceeded' "$login_file" | head -1)"
# the type whose body encloses onLoginSucceeded: follow brace depth, so a nested type declared
# before the function (enum State { ... }) is not taken for its owner
owner="$(awk '
  { line = $0 }
  line ~ /func onLoginSucceeded/ { print top; exit }
  match(line, /(class|struct|enum|actor|extension) [A-Za-z0-9_]+/) { split(substr(line, RSTART, RLENGTH), a, " "); pend = a[2] }
  { o = gsub(/\{/, "{", line); c = gsub(/\}/, "}", line)
    for (i = 0; i < o; i++) { depth++; owner_at[depth] = pend; pend = "" }
    for (i = 0; i < c; i++) { owner_at[depth] = ""; depth-- }
    top = ""; for (i = depth; i >= 1; i--) if (owner_at[i] != "") { top = owner_at[i]; break } }
' "$login_file")"
recv="$owner()"; grep -Eq 'static func onLoginSucceeded|class func onLoginSucceeded' <<<"$sig" && recv="$owner"
label="$(sed -E 's/.*func (onLoginSucceeded\([^)]*\)).*/\1/' <<<"$sig")"
call="$recv.onLoginSucceeded(userId: userId)"
case "$sig" in *async*throws*|*async*) call="Task { @MainActor in _ = try? await $call }" ;; *throws*) call="_ = try? $call" ;; esac
mkdir -p "$work/Sources/RTHarness" "$work/RTUITests"
sed -e "s|/\*RT_CALL\*/|$call|" -e "s|/\*RT_CALL_TEXT\*/|$recv.$label|" "$HERE/RTHarness.swift.tmpl" > "$work/Sources/RTHarness/RTHarness.swift"
cp "$HERE/RTHarnessLoader.m" "$work/Sources/RTHarness/"
cp "$HERE/RTUITests.swift" "$HERE/RTSignin.swift" "$work/RTUITests/"
cat > "$work/rt-project.yml" <<YML
include: [project.yml]
targets:
  RTUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [RTUITests]
    dependencies: [{ target: $app_target }]
    settings: { base: { GENERATE_INFOPLIST_FILE: YES } }
schemes:
  RTRun:
    build: { targets: { $app_target: all, RTUITests: [test] } }
    test: { targets: [RTUITests] }
YML
: > "$work/rt.xcconfig"
if [ -z "$RT_BUILD_SETTINGS" ] && [ -n "$RT_ENV_NAMES" ]; then
  step launch false "the app reads the App ID only from the environment ($RT_ENV_NAMES), which is empty when it is opened from the home screen; read it from an Info.plist key filled by a build setting"
  exit 1
fi
for n in $RT_BUILD_SETTINGS; do printf '%s = %s\n' "$n" "$RT_APP_ID" >> "$work/rt.xcconfig"; done
( cd "$work" && xcodegen generate --spec rt-project.yml ) > "$out/xcodegen.log" 2>&1 || { step launch false "xcodegen failed (xcodegen.log)"; exit 1; }
proj="$(cd "$work" && ls -d ./*.xcodeproj | head -1)"

# --- simulator for this run --------------------------------------------------------------------
dtype="${RT_SIMULATOR:-iPhone 17 Pro}"
runtime="$(xcrun simctl list runtimes -j | jq -r '[.runtimes[] | select(.platform == "iOS" and .isAvailable)] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier')"
udid="$(xcrun simctl create "rt-$(basename "$work")" "$dtype" "$runtime" 2>/dev/null)" || { echo "SKIP: cannot create a '$dtype' simulator on $runtime"; exit 2; }
cleanup() { xcrun simctl shutdown "$udid" >/dev/null 2>&1; xcrun simctl delete "$udid" >/dev/null 2>&1; }
trap cleanup EXIT
# an app with its own sign-in form is signed in through that form, the way a user does, and the hook
# is left unused (lib/signin-form.sh says how a form is recognized)
signin_form="$(bash "$RT_HERE/lib/signin-form.sh" ios "$work/Sources")"
echo "simulator $udid ($dtype, $runtime) | app target $app_target | sign-in: $([ $signin_form = 1 ] && echo "the app's own form" || echo "hook $call")"

dd="$work/DerivedData"; spm="$tools/spm-cache"; mkdir -p "$spm"
xb=(xcodebuild -project "$proj" -scheme RTRun -destination "id=$udid" -derivedDataPath "$dd" -clonedSourcePackagesDirPath "$spm" -xcconfig "$work/rt.xcconfig")
echo "building (first build resolves Swift packages; several minutes)"
if ! ( cd "$work" && "${xb[@]}" build-for-testing ) > "$out/xcodebuild-build.log.raw" 2>&1; then
  step launch false "build failed: $(grep -E 'error:' "$out/xcodebuild-build.log.raw" | head -1 | sed 's/^.*error: //' | cut -c1-200)"
  exit 1
fi

# --- run: UI test (user A) and peer (user B) side by side ----------------------------------------
# digits only: a letter tag ("55dck") hit the test app's profanity filter and the server stored
# the whole message as asterisks (2026-10-14)
tag="$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 6)"
export RT_CHANNEL="rt-chan-$tag" RT_TEXT_B1="hello A from B $tag" RT_TEXT_A1="hello B from A $tag" RT_TEXT_B2="still there A $tag"
mkdir -p "$out/screens"; rm -f "$out/.rt-release" "$out/.rt-abort" "$out/.rt-a2-seen" "$out/.rt-file-seen"
if [ "$RT_RICH" = 1 ]; then
  . "$RT_HERE/lib/rich.sh"
  rich_texts "$tag"
  # a photo in the simulator's library for the attachment step
  rich_image "$work/rt-image.png"
  xcrun simctl boot "$udid" >/dev/null 2>&1
  xcrun simctl addmedia "$udid" "$work/rt-image.png" || step rich-setup false "could not add a photo to the simulator's library"
  # the photo library permission a user grants on first use (the system alert is outside the app)
  app_bundle="$(ls -d "$dd"/Build/Products/*-iphonesimulator/*.app 2>/dev/null | grep -v -- '-Runner.app$' | head -1)"
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_bundle/Info.plist" 2>/dev/null)"
  [ -n "$bundle_id" ] && xcrun simctl privacy "$udid" grant photos "$bundle_id" >/dev/null 2>&1 \
    || step rich-setup false "could not grant photo library access to the app"
fi
# TEST_RUNNER_<name> reaches the UI test process as <name>
runner_env=(TEST_RUNNER_RT_USER_A="$RT_USER_A" TEST_RUNNER_RT_STEPS_FILE="$out/steps.jsonl" TEST_RUNNER_RT_OUT="$out"
  TEST_RUNNER_RT_SHOTS="$out/screens" TEST_RUNNER_RT_CHAT_UI="$RT_CHAT_UI" TEST_RUNNER_RT_SIGNIN_FORM="$signin_form" TEST_RUNNER_RT_DIRECT="$RT_DIRECT" TEST_RUNNER_RT_CHANNEL="$RT_CHANNEL"
  TEST_RUNNER_RT_TEXT_B1="$RT_TEXT_B1" TEST_RUNNER_RT_TEXT_A1="$RT_TEXT_A1" TEST_RUNNER_RT_TEXT_B2="$RT_TEXT_B2"
  TEST_RUNNER_RT_EXPECT_TEXT="$RT_EXPECT_TEXT" TEST_RUNNER_RT_EXPECT_SELECTOR="$RT_EXPECT_SELECTOR"
  TEST_RUNNER_RT_RICH="$RT_RICH" TEST_RUNNER_RT_TEXT_A1_EDITED="${RT_TEXT_A1_EDITED:-}" TEST_RUNNER_RT_TEXT_A2="${RT_TEXT_A2:-}" TEST_RUNNER_RT_SEARCH="${RT_SEARCH:-}")
[ "$RT_DIRECT" = 1 ] && peer touch "$RT_USER_B" >/dev/null
( cd "$work" && env "${runner_env[@]}" "${xb[@]}" test-without-building ) > "$out/xcodebuild-test.log.raw" 2>&1 &
test_pid=$!

if pres="$(peer presence "$RT_USER_A" online 240)"; then
  step connect true "server reports $RT_USER_A online"
  if [ "$RT_CHAT_UI" = 1 ] && kill -0 "$test_pid" 2>/dev/null; then
    if [ "$RT_DIRECT" = 1 ]; then
      found="$(peer find-expect "$RT_USER_B" "$RT_USER_A" "$RT_TEXT_A1" 240)"
      url="$(jq -r '.channelUrl // empty' <<<"$found")"
      if jq -e '.ok' <<<"$found" >/dev/null; then
        step message-a-sends true "$RT_USER_B received A's \"$RT_TEXT_A1\" in the 1:1 channel the app opened"
        peer send "$RT_USER_B" "$url" "$RT_TEXT_B2" >/dev/null || step message-b-sends false "peer could not send the reply"
      else
        step message-a-sends false "$RT_USER_B never received \"$RT_TEXT_A1\": $(jq -r '.error // "no matching message"' <<<"$found")"; touch "$out/.rt-abort"
      fi
    else
      seeded="$(peer seed "$RT_USER_B" "$RT_USER_A" "$RT_CHANNEL" "$RT_TEXT_B1" ${RT_B_CUSTOM_TYPE:+"$RT_B_CUSTOM_TYPE"})"
      url="$(jq -r '.channelUrl // empty' <<<"$seeded")"
      if [ -n "$url" ]; then
        if peer expect "$RT_USER_B" "$url" "$RT_USER_A" "$RT_TEXT_A1" 240 >/dev/null; then
          step message-a-sends true "server has A's \"$RT_TEXT_A1\""
          peer send "$RT_USER_B" "$url" "$RT_TEXT_B2" >/dev/null || step message-b-sends false "peer could not send the live message"
          rich_url="$url"
          [ "$RT_RICH" = 1 ] && rich_wait_a2 "$url" && { a2_sent=1; touch "$out/.rt-a2-seen"; }
          [ "$RT_RICH" = 1 ] && kill -0 "$test_pid" 2>/dev/null && rich_wait_file "$url"; touch "$out/.rt-file-seen"
        else
          step message-a-sends false "B never received \"$RT_TEXT_A1\""
          touch "$out/.rt-abort"
        fi
      else
        step channel-seed false "peer could not open a channel: $(jq -r '.error // "?"' <<<"$seeded")"
        touch "$out/.rt-abort"
      fi
    fi
  fi
else
  step connect false "$(jq -r --arg u "$RT_USER_A" '.error // "server reports \($u) \(.status // "unknown") after 240s"' <<<"$pres")"
  touch "$out/.rt-abort"
fi
touch "$out/.rt-release"
wait "$test_pid"; test_rc=$?
[ "$RT_RICH" = 1 ] && [ -n "${rich_url:-}" ] && rich_server "$rich_url" "$RT_TEXT_B1" "$RT_TEXT_A1" "${a2_sent:-0}"
log="$out/xcodebuild-test.log.raw"
if grep -q "crashed\|Crash:" "$log"; then step no-crash false "the app crashed: $(grep -m1 -E 'crashed|Crash:' "$log" | cut -c1-200)"; fi
# an XCUITest error of its own (not the summary of failed steps the test reports itself)
xc_err="$(grep -m1 -E 'error: -\[RTUITests' "$log" | sed -E 's/^.*testRuntime\] : (failed - )?//' | cut -c1-240)"
if [ "$test_rc" -ne 0 ] && [ -n "$xc_err" ] && ! grep -qF "$(cut -c1-60 <<<"$xc_err")" <(jq -r 'select(.ok==false) | "\(.step): \(.detail)"' "$out/steps.jsonl"); then
  step ui-test false "UI test stopped: $xc_err"
elif [ "$test_rc" -ne 0 ] && ! grep -q '"ok":false' "$out/steps.jsonl"; then
  step ui-test false "UI test failed: $(grep -m1 -E 'error:|Failing tests|TEST FAILED' "$log" | cut -c1-200)"
fi
rm -f "$out/.rt-release" "$out/.rt-abort" "$out/.rt-a2-seen" "$out/.rt-file-seen"
exit 0
