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
- `DirectCallVideo.kt` — `DirectCallViewModel` (incoming-call listener, `dialVideo`, `accept`, `end`,
  exposed as `StateFlow<DirectCall?>`) and a `DirectCallVideo(call)` composable: remote video full
  screen, local preview in the corner, both `SendBirdVideoView` in `AndroidView`.

## How to splice
1. Gradle: `implementation("com.sendbird.sdk:sendbird-calls:1.12.5")`.
2. Keep `SendBirdCall.init(...)` + `authenticate(...)` as in `templates/android/view/calls/SetupCalls.java`.
3. Copy `DirectCallVideo.kt`, adjust the package. Request `CAMERA` and `RECORD_AUDIO` at runtime
   before `dialVideo(...)` or `accept(...)`.
4. Drive it from a composable:
   ```kotlin
   @Composable
   fun CallScreen(vm: DirectCallViewModel = viewModel()) {
       val call by vm.call.collectAsState()
       call?.let { DirectCallVideo(it, Modifier.fillMaxSize()) }
   }
   ```
5. App ID from BuildConfig/secret — never hard-code; the access token is a secret.

## Notes (see knowledge/curated/android/products/calls.md, all cited)
- `onRinging` sets the call's `DirectCallListener` before `accept(...)`, as the README requires.
- Background calls arrive through FCM: pass the data to `SendBirdCall.handleFirebaseMessageData(...)`.
