<!-- last-verified-against: sendbird-calls-ios 1.12.2 -->
<!-- status: populated -->
# ios calls

> Verified against the public mirror `sendbird/sendbird-calls-ios` (README implementation guide, verified 2026-06-09). configure + authenticate + dial build-verified locally (xcodebuild, generic/platform=iOS device arch; the binary framework's simulator slice has an arch limit in this Xcode). Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-calls-ios

## Overview
Sendbird Calls adds voice/video calls. **Direct calls** are 1:1: the caller dials a callee's user ID, the callee's authenticated devices ring, and accepting connects them. Requires iOS 14+ and the WebRTC framework (pulled via SPM).

## Install (SPM only)
- CocoaPods/Carthage are no longer supported. SPM package `https://github.com/sendbird/sendbird-calls-ios`, product `SendBirdCalls` (pulls `sendbird-webrtc-ios`). `import SendBirdCalls`.

## Camera and microphone permissions
Users must grant the app access to the microphone for audio calls and to the camera for video calls. Add `NSMicrophoneUsageDescription` and `NSCameraUsageDescription` to the app's `Info.plist`. To receive calls through VoIP push, also enable Background Modes with Voice over IP under Signing & Capabilities and add CallKit and PushKit. (source: https://sendbird.com/docs/calls/sdk/v1/ios/getting-started/make-first-call — Step 3 and the VoIP notifications note)

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

## Receive calls in the background or after the app was closed (PushKit + CallKit)
The docs say `didStartRinging` alone delivers incoming calls only while the app is in the foreground: "if both CallKit and PushKit are implemented, the Calls SDK will be able to receive incoming calls even when the app is in the background or closed." The SDK receives these calls only through PushKit, so the app reports each one to CallKit from `didStartRinging`. (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/voip-push-notifications)

Wiring, as in Sendbird's public Direct Call QuickStart:
- Turn on the Push Notifications capability and the Background Modes "Voice over IP" mode, and upload the VoIP credential in the dashboard by following the docs page above.
- At launch, add the Calls delegate and create a `PKPushRegistry` for `.voIP`. In `pushRegistry(_:didUpdate:for:)` register the token with `registerVoIPPush(token:unique:completionHandler:)`. The user must be authenticated first; if the token arrives earlier, keep it and register it after `authenticate` succeeds.
- Forward every incoming VoIP push to `pushRegistry(_:didReceiveIncomingPushWith:for:completionHandler:)` on `SendBirdCall`. Its handler receives the call's UUID, or `nil` when the push did not produce a call; the sample then reports a placeholder call and ends it right away.
- In `didStartRinging(_:)`, report the call with CallKit's `reportNewIncomingCall(with:update:completion:)`, using `call.callUUID` as the CallKit UUID.
- In the `CXProviderDelegate`, find the call with `getCall(forUUID:)`; answer with `accept(with:)` and end with `end()`. Pass CallKit's audio session to `audioSessionDidActivate(_:)` and `audioSessionDidDeactivate(_:)`.

<!-- compile: receiver IncomingCallCoordinator -->
```swift
import AVFoundation
import CallKit
import PushKit
import SendBirdCalls

final class IncomingCallCoordinator: NSObject, PKPushRegistryDelegate, SendBirdCallDelegate, CXProviderDelegate {
    private let voipRegistry = PKPushRegistry(queue: .main)
    private let provider = CXProvider(configuration: CXProviderConfiguration())

    // Call after SendBirdCall.configure(appId:) at launch.
    func start() {
        SendBirdCall.addDelegate(self, identifier: "incoming-calls")
        provider.setDelegate(self, queue: .main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // The user must be authenticated before this call succeeds.
        SendBirdCall.registerVoIPPush(token: pushCredentials.token, unique: false) { error in }
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType, completion: @escaping () -> Void) {
        SendBirdCall.pushRegistry(registry, didReceiveIncomingPushWith: payload, for: type) { uuid in
            if uuid == nil {
                // Every VoIP push must be reported to CallKit; report a placeholder and end it.
                let placeholder = UUID()
                let update = CXCallUpdate()
                update.remoteHandle = CXHandle(type: .generic, value: "invalid")
                self.provider.reportNewIncomingCall(with: placeholder, update: update) { _ in
                    self.provider.reportCall(with: placeholder, endedAt: Date(), reason: .failed)
                }
            }
            completion()
        }
    }

    func didStartRinging(_ call: DirectCall) {
        guard let uuid = call.callUUID else { return }
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.caller?.userId ?? "Unknown")
        update.hasVideo = call.isVideoCall
        provider.reportNewIncomingCall(with: uuid, update: update) { error in }
    }

    func providerDidReset(_ provider: CXProvider) {}

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let call = SendBirdCall.getCall(forUUID: action.callUUID) else { action.fail(); return }
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: call.isVideoCall, useFrontCamera: true)
        call.accept(with: AcceptParams(callOptions: options))
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        SendBirdCall.getCall(forUUID: action.callUUID)?.end()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        SendBirdCall.audioSessionDidActivate(audioSession)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        SendBirdCall.audioSessionDidDeactivate(audioSession)
    }
}
```

(source: https://github.com/sendbird/quickstart-calls-directcall-ios/blob/2ebe32e1f6abcf2dc08ee9a23d67ce69ad05d3de/QuickStart/AppDelegate.swift#L41-L45 — delegate and VoIP registry at launch) (source: https://github.com/sendbird/quickstart-calls-directcall-ios/blob/2ebe32e1f6abcf2dc08ee9a23d67ce69ad05d3de/QuickStart/AppDelegate%2BVoIPPush.swift#L15-L55 — token registration, forwarding, placeholder call) (source: https://github.com/sendbird/quickstart-calls-directcall-ios/blob/2ebe32e1f6abcf2dc08ee9a23d67ce69ad05d3de/QuickStart/AppDelegate%2BSendBirdCallsDelegates.swift#L16-L40 — `didStartRinging` reports to CallKit) (source: https://github.com/sendbird/quickstart-calls-directcall-ios/blob/2ebe32e1f6abcf2dc08ee9a23d67ce69ad05d3de/QuickStart/CXExtensions/CXCallManager.swift#L109-L189 — answer, end, audio session) (SendBirdCalls.swiftinterface 1.12.3: `DirectCall.accept(with:)` 112, `end()` 113, `PushRegistryHandler` 448, `didStartRinging(_:)` 650, `DirectCall` 680 with `callUUID` 694, `caller` 697, `isVideoCall` 760, `CallOptions` initializer 829, `addDelegate(_:identifier:)` 863, `getCall(forUUID:)` 870, `pushRegistry(_:didReceiveIncomingPushWith:for:completionHandler:)` 883, `registerVoIPPush(token:unique:completionHandler:)` 884, `audioSessionDidActivate(_:)` 897, `audioSessionDidDeactivate(_:)` 898, `AcceptParams(callOptions:)` 917)

The QuickStart registers with `unique: true`, which keeps only this device's token. Use `unique: false` when the same user should ring on several devices (see "Only the most recently used device gets push notifications" in knowledge/curated/ios/cross-cutting/troubleshooting.md).

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
