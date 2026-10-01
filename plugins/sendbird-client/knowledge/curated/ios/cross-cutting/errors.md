<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: enum-diff-ios -->
<!-- status: populated -->
# ios — errors

> Error codes read verbatim from the SDK's own `SendbirdChatSDK.swiftinterface` enums `ChatError` (SBChatError) and `CoreError` (SBCoreError), verified 2026-09-30. Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes.

## How errors surface
SDK callbacks return an `SBError`; its `code` matches the enum below. `SBError` is also passed to `SessionDelegate.sessionDidHaveError(_:)`.

## Common codes (source: SendbirdChatSDK.swiftinterface ChatError/CoreError)
| Code | iOS symbol | Meaning / typical cause |
|------|-----------|--------------------------|
| 400108 | `nonAuthorized` | Not authorized for the request |
| 400109 | `tokenExpired` | Auth token expired — refresh via SessionDelegate |
| 400111 | `invalidParameterValue` | Invalid parameter value |
| 400201 | `notFoundInDatabase` | Resource not found |
| 400202 | `duplicatedData` | Duplicated data |
| 400203 | `reachedMaxCount` | Max count reached |
| 400300 | `userDeactivated` | User is deactivated |
| 400301 | `userNotExist` | User does not exist |
| 400302 | `accessTokenNotValid` | Access token not valid |
| 400304 | `appIdNotValid` | Application ID not valid |
| 400309 | `sessionKeyExpired` | Name and value from the SDK enum; the public error-codes page has no entry |
| 400310 | `sessionTokenRevoked` | Session token revoked |
| 400401 | `invalidApiToken` | Invalid API token |
| 500901 | `internalServerError` | Internal server error |
| 500910 | `rateLimitExceeded` | Rate limit exceeded — back off |
| 800100 | `invalidInitialization` | SDK not initialized |
| 800101 | `connectionRequired` | Must connect before this call |
| 800110 | `invalidParameter` | Invalid parameter (client-side) |
| 800120 | `networkError` | Unstable network or an unexpected error in the Chat SDK network library |
| 800121 | `networkRoutingError` | Request routing to the Sendbird server failed |
| 800180 | `ackTimeout` | Server did not respond to the request within ten seconds |
| 800190 | `loginTimeout` | Server did not respond to the login request within ten seconds |
| 800200 | `webSocketConnectionClosed` | WebSocket closed |
| 800210 | `webSocketConnectionFailed` | WebSocket connection failed |
| 800250 | `fileUploadTimeout` | File upload timed out |
| 800260 | `fileSizeLimitExceeded` | File exceeds size limit |
| 800500 | `passedInvalidAccessToken` | Session refresh failed because the token passed back was invalid |
| 800501 | `sessionKeyRefreshSucceeded` | Session expired and was refreshed with the given token |
| 800502 | `sessionKeyRefreshFailed` | Session expired and could not be refreshed with the given token |

800120, 800121, 800180, 800190 rows (source: SendbirdChatSDK.swiftinterface (4.39.10) lines 1547–1548, 1562–1563; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

800500–800502 rows (source: SendbirdChatSDK.swiftinterface (4.39.10) lines 1556–1558; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

## Handling tips
- `tokenExpired` (400109) / `sessionKeyExpired` (400309) / `sessionTokenRevoked` (400310): refresh the token through `SessionDelegate` (see auth).
- `connectionRequired` (800101): call `SendbirdChat.connect(...)` first.
- `rateLimitExceeded` (500910): exponential backoff.

## Diagnosing connection failures

Read the code first: `networkError` (800120) is an unstable network or a network-library error, `networkRoutingError` (800121) means routing to the Sendbird server failed, `loginTimeout` (800190) and `ackTimeout` (800180) mean the server did not answer within ten seconds, and `webSocketConnectionFailed` (800210) means the WebSocket could not be established. To see what the SDK's automatic reconnection is doing, register a `ConnectionDelegate`; `didDelayConnection(retryAfter:)` fires when the server is overloaded and tells you the delay before the SDK retries.

```swift
import SendbirdChatSDK

final class ConnectionObserver: ConnectionDelegate {
    func start() { SendbirdChat.addConnectionDelegate(self, identifier: "connection-observer") }
    func stop()  { SendbirdChat.removeConnectionDelegate(forIdentifier: "connection-observer") }
    func didStartReconnection() { }
    func didSucceedReconnection() { }
    func didFailReconnection() { }
    func didDelayConnection(retryAfter: UInt) { }
}

func isNetworkError(_ error: SBError) -> Bool {
    error.code == ChatError.networkError.rawValue
        || error.code == ChatError.networkRoutingError.rawValue
}
```

(source: SendbirdChatSDK.swiftinterface (4.39.10) lines 1547–1551, 1562–1563, 1694–1701, 6364–6365; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes; https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-connection-delegates/add-or-remove-a-connection-delegate)

## Related
- Auth/session: knowledge/curated/ios/products/auth.md
- Full code reference: https://sendbird.com/docs (the bare /docs/chat/sdk/v4/<platform> index paths 404; deep pages resolve)
