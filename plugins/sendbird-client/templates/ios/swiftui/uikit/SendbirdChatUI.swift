// source: https://github.com/sendbird/sendbird-swiftui-ios (README quickstart steps 3-5 and
//   Sample/QuickStartSwiftUI/LoginView.swift initializeSendbird(), verified 2026-09-30)
//   + SendbirdSwiftUI.swiftinterface 1.2.2 (verified 2026-09-30): GroupChannelListView init() line 898,
//   GroupChannelView init(provider:...) line 1634, GroupChannelViewProvider init(channelURL:...) line 1144,
//   SBUGlobals.accessToken / currentUser lines 10507-10508, SBUUser init(userId:nickname:profileURL:) line 20059,
//   SendbirdUI.initialize(applicationId:initParamsBuilder:startHandler:migrationHandler:completionHandler:) line 21361,
//   SendbirdUI.connect(completionHandler:) line 21364, SendbirdUI.disconnect(completionHandler:) line 21379;
//   InitParams.isLocalCachingEnabled / needsSynchronous: SendbirdChatSDK.swiftinterface 4.39.11 lines 3683, 3691.
// Build-verified with tools/templates/compile-check-ios.sh (xcodebuild BUILD SUCCEEDED against pinned and
// latest SendbirdSwiftUI). SwiftUI-native: these are SwiftUI Views, no UIViewControllerRepresentable needed.
// SPM: github.com/sendbird/sendbird-swiftui-ios, product SendbirdSwiftUI (iOS 15+).
// App ID from env/build setting; access token is a secret — never hard-code.

import Foundation
import Combine
import SwiftUI
import SendbirdSwiftUI

private let swiftUIKitAppId = ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"

/// Drives SendbirdSwiftUI init + connect and exposes the phase so the root view can show a
/// loading indicator until the SDK is ready (the README recommends showing one between
/// `startHandler` and `completionHandler`).
@MainActor
final class SendbirdChatUISession: ObservableObject {
    enum Phase { case idle, initializing, connected, failed(String) }

    @Published private(set) var phase: Phase = .idle

    /// Call once (e.g. from `.task` on the root view). Sets `SBUGlobals.currentUser` before connecting,
    /// which SendbirdSwiftUI requires before any of its views appear.
    func start(userId: String, nickname: String? = nil, accessToken: String? = nil) {
        guard case .idle = phase else { return }
        phase = .initializing
        SendbirdUI.initialize(
            applicationId: swiftUIKitAppId,
            initParamsBuilder: { params in
                params?.isLocalCachingEnabled = true
                params?.needsSynchronous = false
            },
            startHandler: { },
            migrationHandler: { },
            completionHandler: { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.phase = .failed("init failed: \(error)")
                        return
                    }
                    SBUGlobals.currentUser = SBUUser(userId: userId, nickname: nickname)
                    SBUGlobals.accessToken = accessToken
                    SendbirdUI.connect { user, error in
                        Task { @MainActor in
                            if user != nil, error == nil {
                                self.phase = .connected
                            } else {
                                self.phase = .failed(error.map { "connect failed: \($0)" } ?? "connect failed")
                            }
                        }
                    }
                }
            }
        )
    }

    func signOut() {
        SendbirdUI.disconnect { [weak self] in
            Task { @MainActor in self?.phase = .idle }
        }
    }
}

/// Root chat screen: shows a spinner while initializing, then the prebuilt channel list.
/// SendbirdSwiftUI views organize navigation internally (README step 5).
struct SendbirdChatRootView: View {
    @ObservedObject var session: SendbirdChatUISession
    let userId: String

    var body: some View {
        switch session.phase {
        case .connected:
            GroupChannelListView()
                .id(userId)   // new user ID -> new view identity -> fresh state (see hosts/swiftui.md)
        case .failed(let message):
            Text(message)
        case .idle, .initializing:
            ProgressView()
        }
    }
}

/// Open one channel directly (e.g. from a push notification) by its channel URL.
struct SendbirdChannelScreen: View {
    let channelURL: String

    var body: some View {
        GroupChannelView(provider: GroupChannelViewProvider(channelURL: channelURL))
    }
}
