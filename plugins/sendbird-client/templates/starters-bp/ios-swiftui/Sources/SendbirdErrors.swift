// source: knowledge/curated/ios/cross-cutting/errors.md ("Handling tips", "Diagnosing connection failures")
// source: https://sendbird.com/docs/chat/sdk/v4/ios/error-codes
import Foundation
import SendbirdChatSDK

/// BP13: show the error code and choose the next step from the verified error table.
struct SendbirdErrorView {
    let code: Int
    let text: String
    /// true when the user has to sign in again (the token or the user is no longer valid)
    let signInAgain: Bool

    /// tokenSent: whether connect sent a session token. Without one, 400302 means the application does
    /// not allow connecting with a user ID alone, or this user has been issued a token; signing in again
    /// sends no token either, so the text points at the token hook instead.
    init(_ error: SBError, tokenSent: Bool = true) {
        code = error.code
        switch error.code {
        case ChatError.accessTokenNotValid.rawValue where !tokenSent:   // 400302
            text = "Sign-in needs a session token (\(error.code)). Return one from TokenProvider.fetchSessionToken."
            signInAgain = true
        case ChatError.userDeactivated.rawValue,          // 400300
             ChatError.userNotExist.rawValue,             // 400301
             ChatError.accessTokenNotValid.rawValue,      // 400302
             ChatError.sessionTokenRevoked.rawValue:      // 400310
            text = "Sign in again (\(error.code))."
            signInAgain = true
        case ChatError.connectionRequired.rawValue:       // 800101
            text = "Not connected yet (\(error.code)). Try again once the status shows Connected."
            signInAgain = false
        case ChatError.networkError.rawValue:             // 800120
            text = "Network problem (\(error.code)). Check the connection and sign in again."
            signInAgain = false
        default:
            text = "Error \(error.code): \(error.localizedDescription)"
            signInAgain = false
        }
    }
}
