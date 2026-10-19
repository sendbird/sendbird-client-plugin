<!-- status: populated -->
# templates/js/react-native/calls

Sendbird Calls (1:1 voice and video) on React Native (`@sendbird/calls-react-native`). From the public RN README,
the "Make first call" docs page, and the package's `lib/typescript` declarations 1.2.0 (verified 2026-10-17).
**Type-checked** with `tools/templates/compile-check-js.sh` (`tsc --noEmit` against `@sendbird/calls-react-native`
1.2.0, `react-native`, and `react-native-permissions`). Not run on a device here.

## Files
- `setup.ts` — `initCalls()`, `authenticate(userId, accessToken?)`, `signOut()`, `requestCallPermissions()`,
  `listenForCalls(onRinging)`, `dial(calleeId, isVideoCall)`, `accept(call)`, `end(call)`. `listenForCalls` and
  `dial` hand back a `DirectCall` (the SDK sends call properties; `SendbirdCalls.getDirectCall` turns them into a call).

## How to splice
1. Install `@sendbird/calls-react-native` and `react-native-permissions` with the project's package manager, then
   follow the RN README for the native side (iOS pods, Android Gradle).
2. iOS Info.plist: `NSMicrophoneUsageDescription` and `NSCameraUsageDescription`. Android: the docs request
   `CAMERA`, `RECORD_AUDIO`, and `BLUETOOTH_CONNECT` at runtime; `requestCallPermissions()` does that before the
   first dial or accept.
3. `initCalls()` and `listenForCalls(...)` once at startup; `await authenticate(userId)` in the app's sign-in code
   (`onLoginSucceeded`, after the Chat connect when the app uses Chat); `await signOut()` in its sign-out code
   (`onLogout`).
4. A call screen: a user ID field with "Voice call" / "Video call" (`dial`), "Accept" / "Decline" while ringing
   (`accept` / `end`), and "End" while dialing or connected. `call.addListener({ onConnected, onEnded })` reports
   the call's progress; `DirectCallVideoView` from the same package shows video.
5. Incoming calls: the native iOS and Android SDKs deliver new incoming calls only through push, also while the
   app is open (their Authentication docs, "WebSocket"), so register `SendbirdCalls.registerPushToken(fcmToken)`
   (Android/APNs) / `SendbirdCalls.ios_registerVoIPPushToken(voipToken)` (iOS VoIP); the `calls-incoming` skill
   covers the rest. Dialing out does not need push.
6. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the
   customer to add a bundler; the access token is a secret.
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/js/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.

## Variations (see knowledge/curated/js/products/calls.md, all cited)
- Direct call dial + listeners follow the RN quickstart.
