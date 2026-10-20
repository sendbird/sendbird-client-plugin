<!-- status: populated -->
# templates/android/compose/calls

Sendbird Calls has **no Compose API**: `javap` of the published sendbird-calls 1.12.4 and 1.12.5 AARs
shows no `androidx.compose` references and the POM has no Compose dependency (verified 2026-09-30).
Video renders into `SendBirdVideoView` (a View), so this template hosts it with `AndroidView`.
Symbols verified with `javap` against both AARs and their sendbird-webrtc 1.0.6998 dependency; call
shapes from the public `sendbird-calls-android` README and the public
`quickstart-calls-directcall-android` `VideoCallActivity.java`. Compiled by
`tools/templates/compile-check-android.sh`.

## Files
- `DirectCallVideo.kt` — `DirectCallViewModel` (incoming-call listener, `dial(calleeId, video)`, `dialVideo`,
  `accept`, `end`, exposed as `call: StateFlow<DirectCall?>` and `state: StateFlow<CallState>` with `IDLE`,
  `DIALING`, `RINGING`, `CONNECTED`) and a `DirectCallVideo(call)` composable: remote video full
  screen, local preview in the corner, both `SendBirdVideoView` in `AndroidView`.

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven` in `settings.gradle` (`sendbird-calls` is not on Maven Central;
   see `knowledge/curated/android/products/calls.md` "Install (Gradle)"), then `implementation("com.sendbird.sdk:sendbird-calls:1.12.5")`.
2. Keep `SendBirdCall.init(...)` + `authenticate(...)` as in `templates/android/view/calls/SetupCalls.java`. `authenticate(...)` goes in the app's sign-in code (`onLoginSucceeded`) and `deauthenticate()` in its sign-out code (`onLogout`).
3. Copy `DirectCallVideo.kt`, adjust the package. Request `SetupCalls.callPermissions()` (`RECORD_AUDIO`,
   `CAMERA`, and `BLUETOOTH_CONNECT` on Android 12+) at runtime before `dial(...)` or `accept(...)`, for example
   with `rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions())`.
4. Drive it from a composable:
   ```kotlin
   @Composable
   fun CallScreen(vm: DirectCallViewModel = viewModel()) {
       val call by vm.call.collectAsState()
       val state by vm.state.collectAsState()
       // RINGING: show Accept (vm.accept(call)) and Decline (vm.end()); DIALING or CONNECTED: show End (vm.end()).
       call?.takeIf { it.isVideoCall }?.let { DirectCallVideo(it, Modifier.fillMaxSize()) }
   }
   ```
5. App ID from BuildConfig/secret — never hard-code; the access token is a secret.
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/android/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.

## Notes (see knowledge/curated/android/products/calls.md, all cited)
- `onRinging` sets the call's `DirectCallListener` before `accept(...)`, as the README requires.
- Incoming calls arrive through FCM, also while the app is open (Authentication docs, "WebSocket"): pass the data to
  `SendBirdCall.handleFirebaseMessageData(...)`. Without FCM, `onRinging` never runs; dialing out still works.
