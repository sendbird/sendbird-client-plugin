// source: knowledge/curated/ios/products/auth.md ("Connect (session token)", "Token rules")
import Foundation

enum TokenProvider {
    /// BP03 / BP04: the one place that asks your server for a Sendbird session token. It returns no
    /// token, which works only with an application that allows connecting with a user ID alone.
    /// Replace the body with a call to your server, and cache the token on the device instead of
    /// issuing a new one on every sign-in. Tokens are secrets: never hard-code, log, or commit them.
    static func fetchSessionToken(userId: String, completion: @escaping (String?) -> Void) {
        _ = userId
        completion(nil)
    }
}
