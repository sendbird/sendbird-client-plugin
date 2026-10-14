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

    init(_ error: SBError) {
        code = error.code
        switch error.code {
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
