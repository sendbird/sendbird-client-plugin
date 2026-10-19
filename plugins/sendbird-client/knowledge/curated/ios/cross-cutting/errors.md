<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- verified-at: 2026-10-10 -->
<!-- verification-method: enum-diff-ios -->
<!-- status: populated -->
# ios — errors

> Error codes read verbatim from the SDK's own `SendbirdChatSDK.swiftinterface` enums `ChatError` (SBChatError) and `CoreError` (SBCoreError), verified 2026-10-10; the table lists every case of both enums. Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes.

## How errors surface
SDK callbacks return an `SBError`; its `code` matches the enum below. `SBError` is also passed to `SessionDelegate.sessionDidHaveError(_:)`.

**Calls errors (1800xxx) are a separate table.** Codes in the 1800xxx range come from the Calls SDK, not Chat, and are not in the table below. Look them up in the "Error codes (1800xxx range)" section of knowledge/curated/ios/products/calls.md.

## All codes (source: SendbirdChatSDK.swiftinterface ChatError/CoreError)
The swiftinterface has no doc comments on these cases, so each meaning comes from the public error-codes pages cited under the table. "No public description" means the code and symbol are verified in the enum but neither page describes the code; do not guess its meaning.

| Code | iOS symbol | Meaning / typical cause |
|------|-----------|--------------------------|
| 400100 | `invalidParameterValueString` | A parameter has an unexpected data type; it should be a string |
| 400101 | `invalidParameterValueNumber` | A parameter has an unexpected data type; it should be a number |
| 400102 | `invalidParameterValueList` | A parameter has an unexpected data type; it should be a list |
| 400103 | `invalidParameterValueJson` | A parameter has an unexpected data type; it should be JSON |
| 400104 | `invalidParameterValueBoolean` | A parameter has an unexpected data type; it should be a boolean |
| 400105 | `invalidParameterValueRequired` | The request is missing one or more required parameters |
| 400106 | `invalidParameterValuePositive` | A parameter is a negative number; it should be a positive number |
| 400107 | `invalidParameterValueNegative` | No public description |
| 400108 | `nonAuthorized` | Not authorized for the request |
| 400109 | `tokenExpired` | The value of the `token` parameter for pagination has expired. This is not a session-token error: the iOS error-codes page does not list 400109, and the Android, Flutter, .NET, and Unity error-codes pages all describe it this way (the last three under the same `tokenExpired` name) |
| 400110 | `invalidChannelURL` | The parameter value is too long (the error-codes pages name 400110 `ParameterValueLengthExceeded`) |
| 400111 | `invalidParameterValue` | Invalid parameter value |
| 400151 | `unusableCharacterIncluded` | A value contains a special character, an empty string, or white space that isn't allowed |
| 400201 | `notFoundInDatabase` | Resource not found |
| 400202 | `duplicatedData` | Duplicated data |
| 400203 | `reachedMaxCount` | Max count reached |
| 400300 | `userDeactivated` | User is deactivated |
| 400301 | `userNotExist` | User does not exist |
| 400302 | `accessTokenNotValid` | Access token not valid |
| 400303 | `authUnknownError` | The session key provided for the request is invalid (the error-codes pages name 400303 `InvalidSessionKeyValue`) |
| 400304 | `appIdNotValid` | Application ID not valid |
| 400305 | `authUserIdTooLong` | The `userId` value is too long |
| 400306 | `authPlanQuotaExceeded` | The request exceeds your plan's paid quota |
| 400309 | `sessionKeyExpired` | Name and value from the SDK enum; the public error-codes page has no entry |
| 400310 | `sessionTokenRevoked` | Session token revoked |
| 400312 | `expiringSessionRequired` | No public description |
| 400313 | `authSessionNotAllowed` | No public description |
| 400401 | `invalidApiToken` | Invalid API token |
| 400402 | `parameterMissing` | The request is missing one or more necessary parameters |
| 400403 | `invalidJsonBody` | The request body is not valid JSON |
| 403200 | `statUploadNotAllowed` | No public description |
| 409000 | `conflict` | No public description |
| 500901 | `internalServerError` | Internal server error |
| 500910 | `rateLimitExceeded` | Rate limit exceeded — back off |
| 800000 | `unknownError` | No public description |
| 800100 | `invalidInitialization` | SDK not initialized |
| 800101 | `connectionRequired` | Must connect before this call |
| 800102 | `connectionCanceled` | The connection was canceled, or the disconnect method was called while the SDK was still connecting |
| 800110 | `invalidParameter` | Invalid parameter (client-side) |
| 800111 | `notSupported` | No public description |
| 800120 | `networkError` | Unstable network or an unexpected error in the Chat SDK network library |
| 800121 | `networkRoutingError` | Request routing to the Sendbird server failed |
| 800130 | `malformedData` | The server response has an invalid data format |
| 800140 | `malformedErrorData` | The error message has an invalid data format because of a problem with the request |
| 800150 | `wrongChannelType` | The channel type specified in the request is invalid |
| 800160 | `markAsReadRateLimitExceeded` | Mark-as-read requests were sent less than a second apart |
| 800170 | `queryInProgress` | A retrieval request for channels, messages, or users arrived while the server was still processing the previous one |
| 800180 | `ackTimeout` | Server did not respond to the request within ten seconds |
| 800190 | `loginTimeout` | Server did not respond to the login request within ten seconds |
| 800191 | `reconnectLoginTimeout` | No public description |
| 800200 | `webSocketConnectionClosed` | WebSocket closed |
| 800210 | `webSocketConnectionFailed` | WebSocket connection failed |
| 800220 | `requestFailed` | The Sendbird server failed to process the request for an internal reason |
| 800221 | `serverOverloaded` | No public description |
| 800230 | `fileUploadCancelFailed` | Canceling a file upload failed because of an unexpected error |
| 800240 | `fileUploadCanceled` | The file upload request was canceled |
| 800250 | `fileUploadTimeout` | File upload timed out |
| 800251 | `fileUploadTimeoutByNetwork` | No public description |
| 800260 | `fileSizeLimitExceeded` | File exceeds size limit |
| 800301 | `timerWasExpired` | An action wasn't completed within a certain time frame (the iOS error-codes page lists `timerWasExpired` as 800310; the SDK enum value is 800301) |
| 800302 | `timerWasAlreadyDone` | An action that should complete once was completed more than once |
| 800400 | `pendingError` | Message status doesn't match |
| 800500 | `passedInvalidAccessToken` | Session refresh failed because the token passed back was invalid |
| 800501 | `sessionKeyRefreshSucceeded` | Session expired and was refreshed with the given token |
| 800502 | `sessionKeyRefreshFailed` | Session expired and could not be refreshed with the given token |
| 800600 | `collectionDisposed` | A message collection or channel collection was used after it had been disposed of |
| 800700 | `localDatabaseError` | The docs state: "The client app attempted to use local database with local caching" |
| 800800 | `notResolved` | No public description |
| 900010 | `socketLoginRequired` | The user isn't logged in to the server |
| 900020 | `socketUserNotMember` | The user isn't a member of the channel |
| 900021 | `socketUserDeactivated` | The user is deactivated |
| 900022 | `socketUserNotOwnerOfMessage` | The user has no permission to edit another user's message |
| 900023 | `socketUserSendMessageNotAllowed` | The user tried to send messages in a channel they aren't a member of |
| 900025 | `socketInvalidMentionForMessage` | The mention type in the request is invalid |
| 900026 | `socketInvalidPushOptionForMessage` | The push option in the request is invalid |
| 900027 | `socketTooManyMetaKeyForMessage` | The message has more metadata keys than allowed |
| 900028 | `socketTooManyMetaValueForMessage` | The message has more metadata values than allowed |
| 900029 | `socketTooManyMetaArrayForMessage` | The message metadata has an invalid value (the iOS error-codes page names 900029 `InvalidMetaArrayForMessage`) |
| 900030 | `socketGuestNotAllowed` | A guest isn't allowed to perform this operation |
| 900040 | `socketMutedUserInApplicationSendMessageNotAllowed` | The user is muted in the application and can't send messages |
| 900041 | `socketMutedUserInChannelSendMessageNotAllowed` | The user is muted in the channel and can't send messages |
| 900050 | `socketChannelFrozen` | The channel is frozen. Operators can still send messages in a frozen channel; other members can't. The error-codes page words this as "no one can send", but the freeze page and the Chat API moderation overview both name the operator exception |
| 900060 | `socketProfanityMessageBlocked` | The message contains a profanity word |
| 900061 | `socketBannedUrlsBlocked` | The message contains a URL that isn't allowed |
| 900065 | `socketRestrictedDomainBlocked` | The request comes from a domain that isn't allowed |
| 900066 | `socketModeratedFileBlocked` | The message contains a file that violates at least one content management policy |
| 900070 | `socketEnterDeletedChannel` | The user tried to enter a deleted channel |
| 900080 | `socketBlockedUserReceiveMessageNotAllowed` | The blocking user tried to send a message to the blocked user in a 1-to-1 distinct channel |
| 900081 | `socketDeactivatedUserReceiveMessageNotAllowed` | The user tried to send a message to a deactivated user in a 1-to-1 distinct channel |
| 900090 | `socketWrongChannelType` | The request specifies a wrong channel type |
| 900100 | `socketBannedUserSendMessageNotAllowed` | The user is banned from the channel and can't send messages |
| 900200 | `socketTooManyMessages` | The number of sent messages exceeds the allowed amount |
| 900300 | `socketMessageNotFound` | The message to edit can't be retrieved |
| 900400 | `socketTooManyParticipants` | The number of channel participants exceeds the allowed amount |
| 900500 | `socketChannelNotFound` | There is no channel to perform this operation on |

800120, 800121, 800180, 800190 rows (source: SendbirdChatSDK.swiftinterface (4.39.10) lines 1547–1548, 1562–1563; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

800500–800502 rows (source: SendbirdChatSDK.swiftinterface (4.39.10) lines 1556–1558; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

400100–400107, 400110, 400151, 400303, 400305, 400306, 400312, 400313, 400402, 400403, 403200, 409000 rows (source: SendbirdChatSDK.swiftinterface (4.39.11) lines 1504–1511, 1514, 1516, 1523, 1525–1526, 1529–1530, 1532–1535; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes ; https://sendbird.com/docs/chat/platform-api/v3/error-codes)

800000, 800102, 800111, 800130–800170, 800191, 800220–800240, 800251, 800301, 800302, 800400, 800600–800800 rows (source: SendbirdChatSDK.swiftinterface (4.39.11) lines 1538, 1541, 1543–1546, 1549, 1552–1555, 1559–1561, 1564–1568, 1923; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

900010–900500 rows (source: SendbirdChatSDK.swiftinterface (4.39.11) lines 1571–1597; https://sendbird.com/docs/chat/sdk/v4/ios/error-codes)

400109 row, pagination token (source: https://sendbird.com/docs/chat/sdk/v4/android/error-codes ; https://sendbird.com/docs/chat/sdk/v4/flutter/error-codes ; https://sendbird.com/docs/chat/sdk/v4/dotnet/error-codes ; https://sendbird.com/docs/chat/sdk/v4/unity/error-codes — reviewed 2026-10-16)

900050 row, operator exception (source: https://sendbird.com/docs/chat/sdk/v4/ios/channel/moderating-a-channel/freeze-and-unfreeze-a-channel ; https://sendbird.com/docs/chat/platform-api/v3/moderation/moderation-overview — reviewed 2026-10-16)

Neither page describes 400107, 400312, 400313, 403200, 409000, 800000, 800111, 800191, 800221, 800251, or 800800. Where a page names a code differently from the iOS symbol (400110, 400303, 900029), the meaning column follows the page and notes the page's name. The iOS page lists `timerWasExpired` under 800310, while the enum value is 800301; that row keeps the enum value.

## Handling tips
- `sessionKeyExpired` (400309) / `sessionTokenRevoked` (400310): refresh the token through `SessionDelegate` (see auth). `tokenExpired` (400109) is an expired pagination token, not an expired session (see the table).
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
