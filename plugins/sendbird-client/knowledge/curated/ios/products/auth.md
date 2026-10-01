<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios auth

> Auth is part of Chat, not a standalone product. Verified against sendbird.com/docs (Chat v4 iOS authentication) and the SDK's `SendbirdChatSDK.swiftinterface`. Connect, session delegate, and disconnect rebuilt against 4.39.10 with xcodebuild on 2026-09-08. Token rules checked against the public docs and the 4.39.10 swiftinterface on 2026-09-30. Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication

## Overview
A user authenticates by connecting with a user ID and (for secured apps) a session/access token issued by your server. A `SessionDelegate` refreshes the token when it expires; disconnect on logout.

## Connect (session token)
```swift
SendbirdChat.connect(userId: USER_ID, authToken: ACCESS_TOKEN) { user, error in
    guard error == nil else { return }
    // authenticated + connected
}
```
Anonymous/dev apps may connect with just `userId`. (source: docs chat v4 ios authentication; build-verified)

## Token refresh — SessionDelegate
Register a delegate BEFORE connecting; set the refresh timeout (60–1800s).
```swift
SendbirdChat.setSessionDelegate(self)
SendbirdChatOptions.setSessionTokenRefreshTimeout(60)

extension MyObject: SessionDelegate {
    func sessionTokenDidRequire(successCompletion success: @escaping (String?) -> Void,
                                failCompletion fail: @escaping () -> Void) {
        // fetch a new token from your server → success(NEW_TOKEN); success(nil) to skip; fail() on error
    }
    func sessionWasClosed() { /* route to login */ }
    func sessionWasRefreshed() { }                 // optional
    func sessionDidHaveError(_ error: SBError) { }  // optional
}
```
(source: SendbirdChatSDK.swiftinterface — `SessionDelegate` (SBDSessionDelegate), `SendbirdChat.setSessionDelegate(_:)`, `SendbirdChatOptions.setSessionTokenRefreshTimeout(_:)`; build-verified)

## Token rules

Once a token has been issued for a user, pass it to `connect(userId:authToken:completionHandler:)` every time that user logs in. Cache the session token on the device and reuse it; issuing a new token on every login can produce simultaneous logins with different tokens, and some of the user's sessions can then be locked out. If `sessionTokenDidRequire(successCompletion:failCompletion:)` calls neither `success` nor `fail` within the refresh timeout (`SendbirdChatOptions.setSessionTokenRefreshTimeout(_:)`, 60–1800 s), the SDK disconnects the socket and the app must call `connect` again.

(source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication; https://sendbird.com/docs/chat/platform-api/v3/user/creating-users/create-a-user; SendbirdChatSDK.swiftinterface (4.39.10) lines 5119, 6794–6803)

## Reauth / multi-device
- Reauth: when `sessionWasClosed()` fires, re-issue a token from your server and reconnect.
- Multi-device: the same `userId` can connect from multiple devices; each maintains its own connection/session.

## Logout
```swift
SendbirdChat.disconnect { }            // clears connection (and local cache on full disconnect)
SendbirdChat.disconnectWebSocket { }   // keep local cache
```
(source: docs chat v4 ios authentication; build-verified)

## Pitfalls
- Set the `SessionDelegate` before `connect`, or token refresh won't be wired.
- Tokens are secrets — never hard-code or log; issue them from your server.

## Related
- Underlying Chat: knowledge/curated/ios/products/chat.md
- Docs: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication
