<!-- status: populated -->
# templates/ios/uikit/calls

Sendbird Calls (1:1 voice and video) on iOS. From the public `sendbird-calls-ios` README and
`SendBirdCalls.swiftinterface` 1.12.3 (verified 2026-10-17; source: https://github.com/sendbird/sendbird-calls-ios/blob/1.12.3/README.md).
**Build-verified** against `SendBirdCalls` (`tools/templates/compile-check-ios.sh`, xcodebuild BUILD SUCCEEDED
for generic/platform=iOS; an app with this file also built for and ran on the arm64 iOS simulator; the 1.12.3 xcframework ships `ios-arm64` and
`ios-arm64-simulator` slices, so an Intel Mac simulator cannot run it).

## Files
- `SetupCalls.swift` (source: templates/ios/uikit/calls/SetupCalls.swift):
  - `SendbirdCallsBootstrap` — `configure()` (also registers the incoming-call delegate),
    `authenticate(userId:accessToken:completion:)`, `deauthenticate(completion:)`, `dial(calleeId:video:)`.
  - `DirectCallController.shared` — one call at a time: `requestPermissions(video:completion:)`,
    `dial(calleeId:video:localView:remoteView:)`, `accept(localView:remoteView:)`, `end()`,
    `attach(local:remote:)`, and `onStateChange` (`idle`, `dialing`, `ringing`, `connected`, `ended`) on the main queue.

## How to splice
1. SPM only: package `https://github.com/sendbird/sendbird-calls-ios`, product `SendBirdCalls` (iOS 14+; pulls WebRTC).
2. Info.plist: add `NSMicrophoneUsageDescription` and, for video calls, `NSCameraUsageDescription`
   (docs "Make first call", Step 3). `requestPermissions(video:completion:)` asks for them before a call.
3. `SendbirdCallsBootstrap.configure()` at launch (for example `application(_:didFinishLaunchingWithOptions:)`).
4. In the app's sign-in code (`onLoginSucceeded`), call `authenticate(userId:accessToken:completion:)` with the
   signed-in user ID; when the app also uses Chat, do it after the Chat connect. In the sign-out code
   (`onLogout`), call `deauthenticate(completion:)`.
5. A call screen: a text field for the callee's user ID and "Voice call" / "Video call" buttons that call
   `DirectCallController.shared.dial(...)`; on `.ringing` show "Accept" / "Decline" (`accept()` / `end()`);
   while dialing or connected show "End" (`end()`). For video, give the controller two `SendBirdVideoView`s.
6. App ID from the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting (see
   `knowledge/curated/ios/setup.md` "App ID") — never hard-code; the access token is a secret.
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/ios/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials, and the `calls-incoming` skill as the next step when this run did not wire incoming-call push). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.

## Notes (see knowledge/curated/ios/products/calls.md, all cited)
- Checked on the arm64 iOS simulator (2026-10-17): sign-in worked and a dial reached a browser, which rang and
  accepted, but the app then aborted inside WebRTC while it set up the audio unit (`AURemoteIO::Initialize`, an
  audio RPC timeout in the simulator). Check call audio and video on a device.
- The callee must be authenticated to Calls before a dial reaches them; a dial to a user who never signed in
  to Calls fails with an error that `onError` reports.
- Incoming calls need VoIP push (PushKit + CallKit) even while the app is open: the Authentication docs say the SDK
  opens its WebSocket only during a call and that "unless you have integrated push notifications to your
  application, new incoming calls won't be delivered through WebSocket". On the iOS simulator without push
  (2026-10-17) the app authenticated, but a call from a browser never reached `didStartRinging`. Wire PushKit and
  CallKit as in `knowledge/curated/ios/products/calls.md` "Receive calls in the background ..."; the
  `calls-incoming` skill sets it up. It needs a real device and the VoIP credential in the dashboard, so it is a
  manual step. Dialing out does not need push.
