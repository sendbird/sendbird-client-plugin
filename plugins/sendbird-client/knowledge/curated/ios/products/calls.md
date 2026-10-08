<!-- last-verified-against: sendbird-calls-ios 1.12.2 -->
<!-- status: populated -->
# ios calls

> Verified against the public mirror `sendbird/sendbird-calls-ios` (README implementation guide, verified 2026-06-09). configure + authenticate + dial build-verified locally (xcodebuild, generic/platform=iOS device arch; the binary framework's simulator slice has an arch limit in this Xcode). Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-calls-ios

## Overview
Sendbird Calls adds voice/video calls. **Direct calls** are 1:1: the caller dials a callee's user ID, the callee's authenticated devices ring, and accepting connects them. Requires iOS 14+ and the WebRTC framework (pulled via SPM).

## Install (SPM only)
- CocoaPods/Carthage are no longer supported. SPM package `https://github.com/sendbird/sendbird-calls-ios`, product `SendBirdCalls` (pulls `sendbird-webrtc-ios`). `import SendBirdCalls`.

## Configure + authenticate
```swift
import SendBirdCalls

SendBirdCall.configure(appId: APP_ID)

let params = AuthenticateParams(userId: userId, accessToken: accessToken)
SendBirdCall.authenticate(with: params) { user, error in
    guard error == nil else { return }
    // authenticated
}
```
Register a VoIP push token with `SendBirdCall.registerVoIPPush(token:unique:)` for background/terminated incoming calls (needs an APNs cert on the dashboard). (source: sendbird-calls-ios README §authenticate; configure + authenticate build-verified)

## Handle incoming calls
<!-- compile: receiver SnippetCallsDelegate -->
```swift
SendBirdCall.addDelegate(self, identifier: UNIQUE_HANDLER_ID)   // SendBirdCallDelegate; didStartRinging(_:)
```
(source: sendbird-calls-ios README §"device-specific event handler")

## Make a call
```swift
let dialParams = DialParams(calleeId: CALLEE_ID, isVideoCall: false, callOptions: CallOptions(), customItems: [:])
let directCall = SendBirdCall.dial(with: dialParams) { directCall, error in
    guard error == nil else { return }
}
```
(source: sendbird-calls-ios README §"make a call"; build-verified)

## Sign out
On logout, deauthenticate the user so this device stops receiving their calls:

```swift
SendBirdCall.deauthenticate { error in
    // signed out of Calls
}
```

`SendBirdCall.deauthenticate(completionHandler:)` is a static method; the handler is optional. (source: SendBirdCalls 1.12.3 `SendBirdCalls.swiftinterface:878`) If you registered a VoIP push token, `SendBirdCall.unregisterVoIPPush(token:completionHandler:)` removes it. (source: SendBirdCalls 1.12.3 `SendBirdCalls.swiftinterface:885`)

## Pitfalls
- SPM-only; the WebRTC dependency is required.
- Add the delegate before expecting `didStartRinging`; delegates are cleared on app termination.
- App ID from config; access token is a secret — never hard-code. VoIP push needs an APNs cert on the dashboard.

## Related
- Repo: https://github.com/sendbird/sendbird-calls-ios
- Remote notifications: see the push section in the repo README (https://github.com/sendbird/sendbird-calls-ios) — the docs URL the README cites is currently 404 (link-check 2026-06-10)
