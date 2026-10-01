// source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication
//   + SendbirdChatSDK.swiftinterface (verified 2026-06-10)
// Build-verified: connect(userId:authToken:) / setSessionDelegate / SessionDelegate /
// setSessionTokenRefreshTimeout / disconnect compile + link against SendbirdChatSDK
// (xcodebuild BUILD SUCCEEDED). Auth is part of Chat. Tokens are secrets — never hard-code.

import Foundation
import SendbirdChatSDK

final class SendbirdSessionManager: NSObject, SessionDelegate {

    // Register before connecting.
    func start() {
        SendbirdChat.setSessionDelegate(self)
        SendbirdChatOptions.setSessionTokenRefreshTimeout(60)   // 60–1800 seconds
    }

    func connect(userId: String, accessToken: String?, completion: @escaping (Bool) -> Void) {
        SendbirdChat.connect(userId: userId, authToken: accessToken) { _, error in
            completion(error == nil)
        }
    }

    func logout() {
        SendbirdChat.disconnect { }
    }

    // MARK: - SessionDelegate
    func sessionTokenDidRequire(successCompletion success: @escaping (String?) -> Void,
                                failCompletion fail: @escaping () -> Void) {
        // Fetch a new token from your server, then: success(NEW_TOKEN)
        // success(nil) to skip refresh; fail() on error.
    }
    func sessionWasClosed() { /* route the user to login */ }
    func sessionWasRefreshed() { }
    func sessionDidHaveError(_ error: SBError) { }
}
