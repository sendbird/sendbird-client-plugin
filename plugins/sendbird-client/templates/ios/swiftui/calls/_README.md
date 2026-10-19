<!-- status: populated -->
# templates/ios/swiftui/calls

Sendbird Calls (1:1 voice/video) on a SwiftUI host. Calls has no SwiftUI-native SDK, so this template is
**SwiftUI interop**: an `ObservableObject` over the verified SDK calls, plus a `UIViewRepresentable`
around the SDK's `SendBirdVideoView`. From the public `sendbird-calls-ios` README and
`SendBirdCalls.swiftinterface` 1.12.3 (verified 2026-09-30). **Build-verified** against `SendBirdCalls` at
the pinned and latest versions (`tools/templates/compile-check-ios.sh`, xcodebuild BUILD SUCCEEDED,
generic/platform=iOS device arch; the 1.12.3 xcframework ships `ios-arm64` and `ios-arm64-simulator` slices, and an
app with the UIKit Calls template built and ran on the arm64 iOS simulator, while an Intel Mac simulator has no slice).

## Files
- `CallsSession.swift`:
  - `CallsSession` — `configure()` / `authenticate(userId:accessToken:)` / `dial(calleeId:video:)` /
    `accept()` / `end()` / `signOut()`, with published `state` (`idle`, `dialing`, `ringing`, `connected`, `ended`) and
    `activeCall`. It is the `SendBirdCallDelegate` (incoming calls) and the call's `DirectCallDelegate`.
  - `CallVideoView(call:source:)` — shows the local or remote video of a `DirectCall`.

## How to splice
1. SPM only: package `https://github.com/sendbird/sendbird-calls-ios`, product `SendBirdCalls` (iOS 14+; pulls WebRTC).
2. Copy `CallsSession.swift` into your app target.
3. Own `CallsSession` at the app root and call `configure()` at launch (for example in the `App`
   initializer or `.task`), so the incoming-call delegate is registered early; then `authenticate(...)` from the
   app's sign-in code (`onLoginSucceeded`, after the Chat connect when the app uses Chat) and `signOut()` from its
   sign-out code (`onLogout`).
4. Drive the UI from `state`: on `.ringing` show accept/decline buttons that call `accept()` / `end()`;
   for video calls place `CallVideoView(call: call, source: .remote)` and `.local` in your layout.
5. App ID from the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting (see `knowledge/curated/ios/setup.md` "App ID") — never hard-code; access token is a secret. Add `NSMicrophoneUsageDescription` and, for video calls,
   Hand-off (`manualSteps`) holds only the steps in `knowledge/curated/ios/products/calls.md` "Manual steps" (App ID, a token server when the app uses tokens, push credentials). No Calls doc has a dashboard step that enables Calls, so never tell the customer to enable Calls.
   `NSCameraUsageDescription` to Info.plist (docs "Make first call", Step 3), and ask for access before the
   first call with AVFoundation's `AVCaptureDevice.requestAccess(for:)`, as `requestPermissions(video:completion:)` in
   `templates/ios/uikit/calls/SetupCalls.swift` does.

## Notes (see knowledge/curated/ios/products/calls.md, all cited)
- Delegate callbacks are `nonisolated` and hop to the main actor: the README says `didStartRinging` runs on
  the calling thread, not on the `SendBirdCall.executeOn(queue:)` queue.
- Incoming calls need VoIP push even while the app is open (Authentication docs, "WebSocket"):
  `SendBirdCall.registerVoIPPush(token:unique:completionHandler:)` plus PushKit/CallKit handling in an
  `@UIApplicationDelegateAdaptor` AppDelegate; that part is not in this template. Dialing out does not need push.
