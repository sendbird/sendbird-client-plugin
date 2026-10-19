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

## Receive a call while the app is open (accept or decline)
Set the call's `DirectCallDelegate` in `didStartRinging(_:)`, then accept with `accept(with:)` or decline with `end()`.

```swift
import SendBirdCalls

final class IncomingCallHandler: NSObject, SendBirdCallDelegate, DirectCallDelegate {
    func didStartRinging(_ call: DirectCall) {
        call.delegate = self
        // Video when the caller placed a video call; call.end() declines instead.
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: call.isVideoCall)
        call.accept(with: AcceptParams(callOptions: options))
    }

    func didConnect(_ call: DirectCall) {}
    func didEnd(_ call: DirectCall) {}
}
```

(source: https://sendbird.com/docs/calls/sdk/v1/ios/features/direct-call) (SendBirdCalls.swiftinterface 1.12.3: `DirectCall.accept(with:)` 112, `end()` 113, `isVideoCall`, `delegate` 763, `SendBirdCallDelegate.didStartRinging(_:)` 650, `DirectCallDelegate` `didConnect(_:)` 656 and `didEnd(_:)` 661, `CallOptions` initializer 829, `AcceptParams(callOptions:)` 917)

`templates/ios/uikit/calls/SetupCalls.swift` (a call controller class) and `templates/ios/swiftui/calls/CallsSession.swift` wrap dial, accept, end, and sign-out with a call state for the UI.

## Receive calls in the background or after the app was closed (PushKit + CallKit)
The VoIP notifications page says: "if both CallKit and PushKit are implemented, the Calls SDK will be able to receive incoming calls even when the app is in the background or closed." (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/voip-push-notifications) The Authentication page adds that push is needed in the foreground too: "WebSocket connections with Sendbird server are made only when there is an ongoing direct call or group call, therefore authenticating won't create unnecessary WebSocket connections. Also, unless you have integrated push notifications to your application, new incoming calls won't be delivered through WebSocket." (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/authentication — "WebSocket") On the iOS simulator (SendBirdCalls 1.12.3, no push, 2026-10-17), an authenticated app never got `didStartRinging` for a call from a browser, which matches the Authentication page. So an app that receives calls needs PushKit, and the app reports each call to CallKit from `didStartRinging`. Dialing out works without push.

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

## Manual steps (what a Calls hand-off may list)
Only these Calls steps need something outside the project, and each has a source:
- **App ID:** create a Sendbird application and copy its App ID from the dashboard; it is case-sensitive. (source: https://sendbird.com/docs/calls/sdk/v1/ios/getting-started/make-first-call)
- **Token server, only when the app signs users in with tokens:** Calls authentication is separate from Chat, and access or session tokens come from the Chat Platform API. (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/authentication)
- **Push credentials, to receive calls:** register the APNs certificate in the dashboard and test on a real device. (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/voip-push-notifications)

None of these pages has a dashboard step that enables or activates Calls (checked 2026-10-17). Do not tell the customer to "enable Calls in the dashboard", and do not add any other dashboard step that no page cited here lists.

## Error codes (1800xxx range)
Calls errors reach your completion handlers as `SBCError?` (for example `AuthenticateHandler`, `DirectCallHandler`, `ErrorHandler`); read the number from `SBCError.errorCode`, a `SBCError.ErrorCode` (Objective-C `SBCErrorCode`) with raw value `Int`. (source: sendbird-calls-ios 1.12.2 `SendBirdCalls.xcframework/ios-arm64/SendBirdCalls.framework/Modules/SendBirdCalls.swiftmodule/arm64-apple-ios.swiftinterface` lines 442-452 and 577-647; the 1.12.3 interface is byte-identical to 1.12.2)

The table lists every case in the 1800xxx range that `SBCError.ErrorCode` ships, with the case name read from that interface (verified 2026-10-19). Meanings come from the public iOS error-codes page; "No public description" means the page has no entry for that code. (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/error-codes)

| Code | `SBCError.ErrorCode` case | Meaning / typical cause |
|------|---------------------------|--------------------------|
| 1800100 | `dialCanceled` | The dialing has been canceled before receiving a callback. |
| 1800101 | `myUserIdNotAllowed` | The caller can't call their own user ID. |
| 1800200 | `requestFailed` | The request failed due to an error from the HTTP library. |
| 1800201 | `websocketConnectionNotOpened` | No public description |
| 1800202 | `websocketConnectionFailed` | No public description |
| 1800203 | `noResponseDueToTimeout` | The request failed to receive a response due to timeout. |
| 1800204 | `requestFailedDueToWebsocketConnectionLost` | The request failed because the websocket connection is lost. |
| 1800205 | `wrongResponse` | The response contains an unexpected object type of data. |
| 1800206 | `queryInProgress` | The previous query is still in progress. |
| 1800207 | `internalServerError` | An internal server error has occurred. |
| 1800208 | `malformedData` | The data format of the response is invalid. |
| 1800300 | `invalidParameterValue` | The parameter specifies an invalid or empty value. |
| 1800301 | `invalidParameterType` | The data type of the parameter is invalid. |
| 1800302 | `instanceNotInitialized` | A SendBirdCall instance is not initialized. |
| 1800303 | `notAuthenticated` | The user is not authenticated. |
| 1800403 | `changingVideoDeviceNotSupported` | No public description |
| 1800404 | `changingVideoDeviceInProgress` | No public description |
| 1800405 | `changingVideoDeviceFailed` | No public description |
| 1800600 | `captureNotAllowedOnAudioCall` | Capturing a video view isn't allowed while on audio call. |
| 1800601 | `videoViewNotReady` | A video view isn't ready to be captured. |
| 1800602 | `videoCallNotConnectedYet` | A video call isn't connected yet therefore can't capture a video view. |
| 1800603 | `failedToGetImageFromVideoStream` | An error occurred while getting an image from the video stream. |
| 1800610 | `callNotConnectedYet` | A call isn't connected yet therefore can't start media recording. |
| 1800611 | `wrongRecordingTypeForAudioCall` | A wrong recording type is selected in an audio call. |
| 1800612 | `recordingAlreadyInProgress` | An ongoing recording session is already in progress. |
| 1800614 | `failedToStartRecording` | A recording session cannot be started due to an error. |
| 1800615 | `failedToStopRecording` | A recording session cannot be stopped due to an error. |
| 1800620 | `screenShareRestrictedFromAudioCall` | Screen share is restricted from audio calls. |
| 1800621 | `screenShareRequestBeforeCallIsConnected` | A call isn't connected yet, but the request for screen share has been made. |
| 1800622 | `screenShareAlreadyInProgress` | The user is trying to share the screen while the previous request is still in progress. |
| 1800623 | `noScreenShareExists` | Screen share doesn't exist but the request to stop sharing the screen has been made. |
| 1800632 | `callPutOnHold` | No public description |
| 1800700 | `clientAlreadyEntered` | The participant is trying to enter the same room they're already in. (docs name: `ParticipantAlreadyInRoom`) |
| 1800701 | `enteringRoomStillInProgress` | The participant is trying to enter the room while the previous request is still in progress. |
| 1800702 | `participantNotInRoom` | The participant is not in the room and the request can't be processed. |
| 1800706 | `localParticipantLostConnection` | The local participant exited the room due to lost connection. |
| 1800707 | `localParticipantKickedOut` | No public description |
| 1800801 | `callAlreadyOnHold` | No public description |
| 1800802 | `callNotPutOnHoldByLocalUser` | No public description |
| 1800803 | `anotherCallInProgress` | No public description |

- The error-codes page also lists `FailedToOpenFile` as 1800613, but the 1.12.2 and 1.12.3 interface has no case for 1800613, so do not write iOS code against it. (source: the interface above; https://sendbird.com/docs/calls/sdk/v1/ios/features/error-codes)
- The page names 1800700 `ParticipantAlreadyInRoom`; the SDK case is `clientAlreadyEntered`. Compare `errorCode` with the SDK case, not the page name.
- The same number can mean something else on another platform. 1800802 is `callNotPutOnHoldByLocalUser` here and in the Android SDK, and `ERR_ACTIVE_CALL_IN_PROGRESS` in the JavaScript and React Native SDKs. Interpret a code with the enum of the platform that raised it.
- The same page lists the server-side codes (for example 400100, 1400126, 500999) in a second table; those are outside the 1800xxx range and are not repeated here. (source: https://sendbird.com/docs/calls/sdk/v1/ios/features/error-codes)

## Pitfalls
- SPM-only; the WebRTC dependency is required.
- Add the delegate before expecting `didStartRinging`; delegates are cleared on app termination.
- App ID from config; access token is a secret — never hard-code. VoIP push needs an APNs cert on the dashboard.

## Related
- Repo: https://github.com/sendbird/sendbird-calls-ios
- Remote notifications: see the push section in the repo README (https://github.com/sendbird/sendbird-calls-ios) — the docs URL the README cites is currently 404 (link-check 2026-06-10)
