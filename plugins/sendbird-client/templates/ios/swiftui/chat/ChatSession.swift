// source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message (verified 2026-06-09)
// SDK calls (InitParams / SendbirdChat.initialize / SendbirdChat.connect / sendUserMessage) are
// identical to the build-verified UIKit-host template (templates/ios/uikit/chat/InitConnect.swift,
// xcodebuild BUILD SUCCEEDED 2026-06-09). This file only wraps those verified calls in an
// ObservableObject so SwiftUI views can observe connection/state — the wrapper is standard
// SwiftUI/Combine, not an SDK API. SPM: github.com/sendbird/sendbird-chat-sdk-ios, product
// SendbirdChatSDK, from 4.0.0. App ID from env/build setting; tokens are secrets — never hard-code.

import Foundation
import Combine
import SendbirdChatSDK

// App ID: the SENDBIRD_APP_ID Info.plist key (set it to $(SENDBIRD_APP_ID) and define that build setting)
// works however the app is launched. The environment variable exists only when Xcode or a test runner
// launches the app, so it is a fallback for development.
private let swiftUIAppId: String = {
    if let value = Bundle.main.object(forInfoDictionaryKey: "SENDBIRD_APP_ID") as? String,
       !value.isEmpty, !value.hasPrefix("$(") {
        return value
    }
    return ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"
}()

/// Observable Chat session for SwiftUI. Inject as a `@StateObject` at the app root and read
/// `currentUser` / `isConnected` from any view.
@MainActor
final class ChatSession: ObservableObject {
    /// The one session the app uses. Start it from the app's own sign-in code and show it from any view,
    /// so sign-in never depends on which view or object happened to receive a reference.
    static let shared = ChatSession()

    @Published private(set) var currentUser: User?
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    /// Call once at launch (e.g. in the App initializer or `.task`).
    func initialize() {
        let params = InitParams(applicationId: swiftUIAppId, isLocalCachingEnabled: true, needsSynchronous: false)
        SendbirdChat.initialize(params: params,
                                migrationStartHandler: { },
                                completionHandler: { [weak self] error in
            if let error = error {
                Task { @MainActor in self?.lastError = "init failed: \(error)" }
            }
        })
    }

    /// Connect after `initialize()`. Authenticated apps pass a token:
    /// `SendbirdChat.connect(userId:authToken:)`.
    func connect(userId: String) {
        SendbirdChat.connect(userId: userId) { [weak self] user, error in
            Task { @MainActor in
                guard let user = user, error == nil else {
                    self?.lastError = error.map { "connect failed: \($0)" } ?? "connect failed"
                    return
                }
                self?.currentUser = user
                self?.isConnected = true
                self?.lastError = nil
            }
        }
    }

    /// Send a text message to an already-loaded GroupChannel.
    func send(_ text: String, to channel: GroupChannel) {
        channel.sendUserMessage(text) { [weak self] message, error in
            if let error = error {
                Task { @MainActor in self?.lastError = "send failed: \(error)" }
            }
        }
    }
}
