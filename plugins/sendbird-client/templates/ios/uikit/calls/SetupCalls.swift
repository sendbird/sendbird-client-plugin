// source: https://github.com/sendbird/sendbird-calls-ios/blob/1.12.3/README.md (README implementation guide: configure, authenticate,
//   "Receive a call", "Make a call", deauthenticate; verified 2026-10-17)
// source: https://sendbird.com/docs/calls/sdk/v1/ios/features/direct-call (accept and end a direct call)
// source: https://sendbird.com/docs/calls/sdk/v1/ios/getting-started/make-first-call (Step 3: camera and microphone usage strings)
// SendBirdCalls.swiftinterface 1.12.3 (verified 2026-10-17): configure(appId:) 858, addDelegate(_:identifier:) 863,
//   authenticate(with:completionHandler:) 877, deauthenticate(completionHandler:) 878, dial(with:completionHandler:) 880,
//   AuthenticateParams(userId:accessToken:) 180, DialParams(calleeId:isVideoCall:callOptions:customItems:) 844,
//   CallOptions(isAudioEnabled:isVideoEnabled:localVideoView:remoteVideoView:useFrontCamera:) 829,
//   AcceptParams(callOptions:) 917, DirectCall.accept(with:) 112 / end() 113,
//   updateLocalVideoView(_:) / updateRemoteVideoView(_:) 164-165, SendBirdCallDelegate 649-650, DirectCallDelegate 654-661.
// Build-verified with tools/templates/compile-check-ios.sh (xcodebuild BUILD SUCCEEDED against pinned and latest
// SendBirdCalls, generic/platform=iOS; an app with this file also built for and ran on the arm64 iOS simulator).
// SPM only: https://github.com/sendbird/sendbird-calls-ios , product SendBirdCalls (iOS 14+).
// App ID from env; access token is a secret — never hard-code.

import AVFoundation
import Foundation
import SendBirdCalls

// App ID: the SENDBIRD_APP_ID Info.plist key (set it to $(SENDBIRD_APP_ID) and define that build setting)
// works however the app is launched. The environment variable exists only when Xcode or a test runner
// launches the app, so it is a fallback for development.
private let appId: String = {
    if let value = Bundle.main.object(forInfoDictionaryKey: "SENDBIRD_APP_ID") as? String,
       !value.isEmpty, !value.hasPrefix("$(") {
        return value
    }
    return ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"
}()

enum SendbirdCallsBootstrap {
    /// Call once at launch, before authenticate, so the incoming-call delegate is in place early.
    static func configure() {
        SendBirdCall.configure(appId: appId)
        DirectCallController.shared.start()
    }

    /// Call from the app's sign-in code (for example onLoginSucceeded), after the Chat connect if the app uses Chat.
    static func authenticate(userId: String, accessToken: String?, completion: @escaping (Bool) -> Void) {
        let params = AuthenticateParams(userId: userId, accessToken: accessToken)
        SendBirdCall.authenticate(with: params) { _, error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }

    /// Call from the app's sign-out code (for example onLogout) so this device stops ringing for the user.
    static func deauthenticate(completion: (() -> Void)? = nil) {
        SendBirdCall.deauthenticate { _ in
            DispatchQueue.main.async { completion?() }
        }
    }

    // Make a 1:1 direct call (kept for code that only dials; DirectCallController also tracks the call).
    static func dial(calleeId: String, video: Bool = false) {
        DirectCallController.shared.dial(calleeId: calleeId, video: video)
    }
}

/// One 1:1 call at a time: incoming (ringing), outgoing (dialing), connected, ended.
/// Drive the UI from `onStateChange`, which always runs on the main queue.
final class DirectCallController: NSObject {
    enum State { case idle, dialing, ringing, connected, ended }

    static let shared = DirectCallController()

    private(set) var state: State = .idle
    private(set) var activeCall: DirectCall?
    /// Called on the main queue with the new state and the call it belongs to.
    var onStateChange: ((State, DirectCall?) -> Void)?
    /// Called on the main queue when dial fails (for example the callee is not signed in to Calls yet).
    var onError: ((String) -> Void)?

    private let delegateIdentifier = "DirectCallController"
    private var started = false

    /// Registers the device-wide delegate that receives incoming calls (didStartRinging).
    func start() {
        guard !started else { return }
        started = true
        SendBirdCall.addDelegate(self, identifier: delegateIdentifier)
    }

    /// Asks for the microphone (and the camera for video) before a call. Needs NSMicrophoneUsageDescription
    /// and NSCameraUsageDescription in Info.plist.
    func requestPermissions(video: Bool, completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
            guard video else {
                DispatchQueue.main.async { completion(audioGranted) }
                return
            }
            AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                DispatchQueue.main.async { completion(audioGranted && videoGranted) }
            }
        }
    }

    /// Places a 1:1 call. Pass video views for a video call; they can also be set later with `attach(local:remote:)`.
    func dial(calleeId: String, video: Bool, localView: SendBirdVideoView? = nil, remoteView: SendBirdVideoView? = nil) {
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: video,
                                  localVideoView: localView, remoteVideoView: remoteView, useFrontCamera: true)
        let params = DialParams(calleeId: calleeId, isVideoCall: video, callOptions: options, customItems: [:])
        let call = SendBirdCall.dial(with: params) { [weak self] _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                self?.onError?("dial failed: \(error)")
                self?.update(.idle, nil)
            }
        }
        call?.delegate = self
        update(.dialing, call)
    }

    /// Accepts the ringing call, with video when the caller placed a video call.
    func accept(localView: SendBirdVideoView? = nil, remoteView: SendBirdVideoView? = nil) {
        guard let call = activeCall else { return }
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: call.isVideoCall,
                                  localVideoView: localView, remoteVideoView: remoteView, useFrontCamera: true)
        call.accept(with: AcceptParams(callOptions: options))
    }

    /// Hangs up, cancels an outgoing call, or declines a ringing one.
    func end() {
        activeCall?.end()
    }

    /// Shows the call's video in views the screen owns.
    func attach(local: SendBirdVideoView, remote: SendBirdVideoView) {
        activeCall?.updateLocalVideoView(local)
        activeCall?.updateRemoteVideoView(remote)
    }

    private func update(_ newState: State, _ call: DirectCall?) {
        state = newState
        activeCall = (newState == .ended || newState == .idle) ? nil : call
        onStateChange?(newState, call)
    }
}

// The README says didStartRinging runs on the calling thread, so every callback hops to the main queue.
extension DirectCallController: SendBirdCallDelegate, DirectCallDelegate {
    func didStartRinging(_ call: DirectCall) {
        call.delegate = self   // register before accepting (README "Receive a call")
        DispatchQueue.main.async {
            if self.activeCall != nil {
                call.end()   // already in a call: decline the second one
                return
            }
            self.update(.ringing, call)
        }
    }

    func didConnect(_ call: DirectCall) {
        DispatchQueue.main.async { self.update(.connected, call) }
    }

    func didEnd(_ call: DirectCall) {
        DispatchQueue.main.async {
            guard self.activeCall == nil || self.activeCall?.callId == call.callId else { return }
            self.update(.ended, call)
        }
    }
}
