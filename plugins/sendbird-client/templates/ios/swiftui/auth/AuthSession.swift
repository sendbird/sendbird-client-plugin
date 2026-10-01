// source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication
//   + SendbirdChatSDK.swiftinterface 4.39.11 (verified 2026-09-30): connect(userId:authToken:) line 6321,
//   disconnect(completionHandler:) line 6341, setSessionDelegate(_:) line 6390,
//   SendbirdChatOptions.setSessionTokenRefreshTimeout(_:) line 5123, SessionDelegate lines 6798-6806.
// SDK calls are the same as the build-verified UIKit-host template (templates/ios/uikit/auth/SessionAuth.swift).
// This file only wraps them in an ObservableObject so SwiftUI views can observe the auth state; the
// wrapper is standard SwiftUI/Combine, not an SDK API. Build-verified with tools/templates/compile-check-ios.sh
// (xcodebuild BUILD SUCCEEDED against pinned and latest SendbirdChatSDK). Auth is part of Chat.
// SPM: github.com/sendbird/sendbird-chat-sdk-ios, product SendbirdChatSDK. Tokens are secrets — never hard-code or log.

import Foundation
import Combine
import SendbirdChatSDK

/// Observable auth state for SwiftUI. Own it at the app root (`@StateObject`) and switch the
/// root view on `status`. Call `SendbirdChat.initialize` first (see templates/ios/swiftui/chat).
@MainActor
final class AuthSession: NSObject, ObservableObject {
    enum Status { case signedOut, connecting, signedIn, sessionClosed }

    @Published private(set) var status: Status = .signedOut
    @Published private(set) var currentUser: User?
    @Published private(set) var lastError: String?

    /// Fetches a fresh session token from YOUR server and passes it to the completion
    /// (nil if it cannot be fetched). Called when the SDK reports the token must be refreshed.
    private let fetchSessionToken: (_ completion: @escaping (String?) -> Void) -> Void

    init(fetchSessionToken: @escaping (_ completion: @escaping (String?) -> Void) -> Void) {
        self.fetchSessionToken = fetchSessionToken
        super.init()
    }

    /// Register the session delegate before `signIn`.
    func start() {
        SendbirdChat.setSessionDelegate(self)
        SendbirdChatOptions.setSessionTokenRefreshTimeout(60)   // 60–1800 seconds
    }

    func signIn(userId: String, sessionToken: String?) {
        status = .connecting
        SendbirdChat.connect(userId: userId, authToken: sessionToken) { [weak self] user, error in
            Task { @MainActor in
                guard let self else { return }
                guard let user, error == nil else {
                    self.lastError = error.map { "connect failed: \($0)" } ?? "connect failed"
                    self.status = .signedOut
                    return
                }
                self.currentUser = user
                self.lastError = nil
                self.status = .signedIn
            }
        }
    }

    func signOut() {
        SendbirdChat.disconnect { [weak self] in
            Task { @MainActor in
                self?.currentUser = nil
                self?.status = .signedOut
            }
        }
    }
}

// MARK: - SessionDelegate
// The SDK may call these off the main thread, so each hops to the main actor before touching state.
extension AuthSession: SessionDelegate {
    nonisolated func sessionTokenDidRequire(successCompletion success: @escaping (String?) -> Void,
                                            failCompletion fail: @escaping () -> Void) {
        Task { @MainActor in
            self.fetchSessionToken { token in
                // success(nil) skips the refresh; fail() reports that the refresh failed.
                if let token { success(token) } else { fail() }
            }
        }
    }

    nonisolated func sessionWasClosed() {
        Task { @MainActor in
            self.currentUser = nil
            self.status = .sessionClosed   // route the user back to login
        }
    }

    nonisolated func sessionWasRefreshed() { }

    nonisolated func sessionDidHaveError(_ error: SBError) {
        Task { @MainActor in self.lastError = "session error: \(error)" }
    }
}
