<!-- status: populated -->
# templates/android/view/calls

Sendbird Calls (1:1 voice and video) on Android. Call shapes from the public "Make first call" docs page and the
`sendbird-calls-android` README; every symbol verified with `javap` against the published sendbird-calls 1.12.5 AAR
(2026-10-17). Compiled by `tools/templates/compile-check-android.sh`.

## Files
- `SetupCalls.java` — `callPermissions()`, `init`, `authenticate`, `deauthenticate`,
  `addIncomingCallListener(handlerId, CallEvents)`, `dial(calleeId, video, CallEvents)`, `accept(call)`, `end(call)`.
  `CallEvents` reports `onRinging`, `onConnected`, `onEnded`, and `onDialFailed` for the call;
  `authenticate(userId, accessToken, done)` reports the result through `CompletionHandler` (`null` means signed in).

## How to splice
1. Gradle: `implementation 'com.sendbird.sdk:sendbird-calls:1.12.5'`.
2. Permissions: the SDK's own manifest already declares `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`,
   `BLUETOOTH`, `BLUETOOTH_CONNECT`, `INTERNET`, and `ACCESS_NETWORK_STATE`, which the manifest merger adds to the
   app; the docs ("Make first call", Step 3) list the same seven `uses-permission` lines for the app's
   `AndroidManifest.xml`. Request `SetupCalls.callPermissions()` at runtime before the first dial or accept
   (for example with `ActivityResultContracts.RequestMultiplePermissions`); `BLUETOOTH_CONNECT` is included on
   Android 12 and later.
3. `SetupCalls.init(context, appId)` and `addIncomingCallListener(...)` in `Application.onCreate`.
4. `authenticate(...)` in the app's sign-in code (`onLoginSucceeded`), after the Chat connect when the app uses
   Chat; `deauthenticate()` in its sign-out code (`onLogout`).
5. A call screen: a field for the callee's user ID and "Voice call" / "Video call" buttons that call
   `dial(calleeId, video, events)`; on `onRinging` show "Accept" / "Decline" (`accept(call)` / `end(call)`); while
   dialing or connected show "End" (`end(call)`). `CallEvents` runs on the SDK's callback thread, so post UI
   updates to the main thread. For video views see `templates/android/compose/calls/DirectCallVideo.kt`
   (`SendBirdVideoView`, a View).
6. App ID from BuildConfig/secret — never hard-code; the access token is a secret.
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/android/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.

## Notes (see knowledge/curated/android/products/calls.md, all cited)
- The callee must be authenticated to Calls before a dial reaches them.
- Incoming calls need FCM push even while the app is open: the Authentication docs say the SDK opens its WebSocket
  only during a call and that "unless you have integrated push notifications to your application, new incoming calls
  won't be delivered through WebSocket". On an emulator without FCM (2026-10-17), the app authenticated and dialed a
  browser that answered, but a call from the browser never rang (`onRinging` never ran). Wire FCM as in
  `knowledge/curated/android/products/calls.md` "Receive calls ... (FCM)"; the `calls-incoming` skill sets it up. It needs
  the customer's Firebase project and FCM credentials in the dashboard, so it is a manual step.
