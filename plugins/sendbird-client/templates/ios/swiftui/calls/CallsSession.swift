// source: https://github.com/sendbird/sendbird-calls-ios/blob/1.12.3/README.md (README "Receive a call", "Make a call", and
//   "Callback and delegate thread handling", verified 2026-09-30)
//   + SendBirdCalls.swiftinterface 1.12.3 (verified 2026-09-30): SendBirdCall.configure(appId:) line 858,
//   addDelegate(_:identifier:) line 863, authenticate(with:completionHandler:) line 877,
//   dial(with:completionHandler:) line 880, AuthenticateParams init line 180, DialParams init line 844,
//   AcceptParams init(callOptions:) line 917, DirectCall.accept(with:) / end() lines 112-113,
//   updateLocalVideoView(_:) / updateRemoteVideoView(_:) lines 164-165, DirectCall.delegate line 763,
//   SendBirdCallDelegate lines 649-650, DirectCallDelegate lines 654-661,
//   SendBirdVideoView init(frame:contentMode:) line 451, deauthenticate(completionHandler:) line 878 (verified 2026-10-17),
//   CallOptions init(isAudioEnabled:isVideoEnabled:localVideoView:remoteVideoView:useFrontCamera:) line 829.
// Calls has no SwiftUI-native SDK: this is SwiftUI interop — an ObservableObject over the verified SDK calls
// plus a UIViewRepresentable around the SDK's SendBirdVideoView (standard SwiftUI, not an SDK API).
// Build-verified with tools/templates/compile-check-ios.sh (xcodebuild BUILD SUCCEEDED against pinned and
// latest SendBirdCalls, generic/platform=iOS device arch).
// SPM only: https://github.com/sendbird/sendbird-calls-ios , product SendBirdCalls (iOS 14+).
// App ID from env; access token is a secret — never hard-code.

import Foundation
import Combine
import SwiftUI
import UIKit
import SendBirdCalls

// App ID: the SENDBIRD_APP_ID Info.plist key (set it to $(SENDBIRD_APP_ID) and define that build setting)
// works however the app is launched. The environment variable exists only when Xcode or a test runner
// launches the app, so it is a fallback for development.
private let callsSwiftUIAppId: String = {
    if let value = Bundle.main.object(forInfoDictionaryKey: "SENDBIRD_APP_ID") as? String,
       !value.isEmpty, !value.hasPrefix("$(") {
        return value
    }
    return ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"
}()

/// Observable 1:1 call state for SwiftUI. Own it at the app root and call `configure()` at launch,
/// so the device-wide delegate is registered before any incoming call arrives.
@MainActor
final class CallsSession: NSObject, ObservableObject {
    /// The one session the app uses. Start it from the app's own sign-in code and show it from any view,
    /// so sign-in never depends on which view or object happened to receive a reference.
    static let shared = CallsSession()

    enum CallState { case idle, dialing, ringing, connected, ended }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var state: CallState = .idle
    @Published private(set) var activeCall: DirectCall?
    @Published private(set) var lastError: String?

    private let delegateIdentifier = "CallsSession"

    func configure() {
        SendBirdCall.configure(appId: callsSwiftUIAppId)
        SendBirdCall.addDelegate(self, identifier: delegateIdentifier)
    }

    func authenticate(userId: String, accessToken: String?) {
        let params = AuthenticateParams(userId: userId, accessToken: accessToken)
        SendBirdCall.authenticate(with: params) { [weak self] _, error in
            Task { @MainActor in
                self?.isAuthenticated = (error == nil)
                if let error { self?.lastError = "authenticate failed: \(error)" }
            }
        }
    }

    /// Sign-out: call from the app's own sign-out code so this device stops ringing for the user.
    func signOut() {
        SendBirdCall.deauthenticate { [weak self] _ in
            Task { @MainActor in
                self?.isAuthenticated = false
                self?.activeCall = nil
                self?.state = .idle
            }
        }
    }

    /// Place a 1:1 call. `video: true` makes it a video call; show it with `CallVideoView`.
    func dial(calleeId: String, video: Bool = false) {
        state = .dialing
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: video)
        let params = DialParams(calleeId: calleeId, isVideoCall: video, callOptions: options, customItems: [:])
        let call = SendBirdCall.dial(with: params) { [weak self] _, error in
            if let error {
                Task { @MainActor in
                    self?.lastError = "dial failed: \(error)"
                    self?.state = .idle
                }
            }
        }
        call?.delegate = self
        activeCall = call
    }

    /// Accept the ringing call, with video when the caller placed a video call.
    func accept() {
        guard let call = activeCall else { return }
        let options = CallOptions(isAudioEnabled: true, isVideoEnabled: call.isVideoCall)
        call.accept(with: AcceptParams(callOptions: options))
    }

    /// Hang up, or decline a ringing call.
    func end() {
        activeCall?.end()
    }
}

// MARK: - SendBirdCallDelegate / DirectCallDelegate
// The README notes didStartRinging runs on the calling thread (not the executeOn queue), so every
// callback hops to the main actor before touching published state.
extension CallsSession: SendBirdCallDelegate, DirectCallDelegate {
    nonisolated func didStartRinging(_ call: DirectCall) {
        call.delegate = self   // register before accepting (README "Receive a call")
        Task { @MainActor in
            self.activeCall = call
            self.state = .ringing
        }
    }

    nonisolated func didConnect(_ call: DirectCall) {
        Task { @MainActor in self.state = .connected }
    }

    nonisolated func didEnd(_ call: DirectCall) {
        Task { @MainActor in
            self.state = .ended
            self.activeCall = nil
        }
    }
}

/// Shows the local or remote video of a DirectCall. Wraps the SDK's `SendBirdVideoView` (a UIView)
/// with standard SwiftUI interop.
struct CallVideoView: UIViewRepresentable {
    enum Source { case local, remote }

    let call: DirectCall
    let source: Source

    func makeUIView(context: Context) -> SendBirdVideoView {
        let view = SendBirdVideoView(frame: .zero, contentMode: .scaleAspectFill)
        switch source {
        case .local: call.updateLocalVideoView(view)
        case .remote: call.updateRemoteVideoView(view)
        }
        return view
    }

    func updateUIView(_ uiView: SendBirdVideoView, context: Context) { }
}
