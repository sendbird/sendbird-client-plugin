<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-10-10 -->
<!-- verification-method: enum-diff-android -->
<!-- status: populated -->
# android — errors

> Every row's code and constant name were read with `javap` from `SendbirdError` in sendbird-common 1.0.7 (a dependency of sendbird-chat 4.36.5) by `tools/curated/error-enum-diff-android.sh` (verified 2026-10-10); the table lists all 71 `ERR_*` constants that class ships. Meanings come from the public Chat v4 Android error-codes page. For server codes (400xxx, 403xxx, 409xxx, 500xxx, 900xxx) the meaning starts with the server error name that page gives; where that name differs from the SDK constant name, the row says so. Rows marked "No public description" have a verified code and constant, but neither the Android error-codes page nor the Platform API error-codes page lists the code. Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes or names.

## How errors surface
SDK callbacks return a `SendbirdException` (`com.sendbird.android.exception.SendbirdException`); its code matches the shared Sendbird error codes. Constants are exposed as `SendbirdError.ERR_*`.

## All codes (code and name: javap of SendbirdError; meaning: public error-codes page)
| Code | Android constant | Meaning / typical cause |
|------|------------------|--------------------------|
| 400100 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_STRING` | `UNEXPECTED_PARAMETER_TYPE`: the request specifies one or more parameters in an unexpected data type; the data type should be string |
| 400101 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_NUMBER` | `UNEXPECTED_PARAMETER_TYPE`: the request specifies one or more parameters in an unexpected data type; the data type should be number |
| 400102 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_LIST` | `UNEXPECTED_PARAMETER_TYPE`: the request specifies one or more parameters in an unexpected data type; the data type should be list |
| 400103 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_JSON` | `UNEXPECTED_PARAMETER_TYPE`: the request specifies one or more parameters in an unexpected data type; the data type should be JSON |
| 400104 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_BOOLEAN` | `UNEXPECTED_PARAMETER_TYPE`: the request specifies one or more parameters in an unexpected data type; the data type should be boolean |
| 400105 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_REQUIRED` | `MISSING_REQUIRED_PARAMETERS`: the request is missing one or more required parameters |
| 400106 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_POSITIVE` | `NEGATIVE_NUMBER_NOT_ALLOWED`: the parameter specifies a negative number; its value should be a positive number |
| 400107 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE_NEGATIVE` | No public description |
| 400108 | `SendbirdError.ERR_NON_AUTHORIZED` | Not authorized |
| 400109 | `SendbirdError.ERR_TOKEN_EXPIRED` | `EXPIRED_PAGE_TOKEN`: the value of the token parameter for pagination has expired (the page's server name differs from this constant's name) |
| 400110 | `SendbirdError.ERR_INVALID_LENGTH` | `PARAMETER_VALUE_LENGTH_EXCEEDED`: the length of the parameter value is too long |
| 400111 | `SendbirdError.ERR_INVALID_PARAMETER_VALUE` | `INVALID_VALUE`: the request specifies an invalid value |
| 400151 | `SendbirdError.ERR_UNUSABLE_CHARACTER_INCLUDED` | `NOT_ALLOWED_CHARACTER`: the request specifies an illegal value containing a special character, an empty string, or white space |
| 400201 | `SendbirdError.ERR_NOT_FOUND_IN_DATABASE` | `RESOURCE_NOT_FOUND`: the resource identified with the request's resourceId parameter can't be found |
| 400202 | `SendbirdError.ERR_DUPLICATED_DATA` | `RESOURCE_ALREADY_EXISTS`: the resource identified with the request's resourceId parameter already exists |
| 400203 | `SendbirdError.ERR_MAX_ITEM_EXCEEDED` | `TOO_MANY_ITEMS_IN_PARAMETER`: the parameter specifies more items than allowed |
| 400300 | `SendbirdError.ERR_USER_DEACTIVATED` | `DEACTIVATED_USER_NOT_ACCESSIBLE`: the request can't retrieve the deactivated user data |
| 400301 | `SendbirdError.ERR_USER_NOT_EXIST` | `USER_NOT_FOUND`: the user identified with the request's USER_ID can't be found because the user doesn't exist or has been deleted |
| 400302 | `SendbirdError.ERR_INVALID_TOKEN` | `INVALID_ACCESS_TOKEN`: the access token provided for the request specifies an invalid value |
| 400309 | `SendbirdError.ERR_SESSION_KEY_EXPIRED` | Constant name and value verified from the SDK (sendbird-common `SendbirdError`); the public error-codes page has no entry for 400309, so no meaning is documented |
| 400310 | `SendbirdError.ERR_SESSION_TOKEN_REVOKED` | Session token revoked |
| 400401 | `SendbirdError.ERR_API_TOKEN_NOT_VALID` | `INVALID_API_TOKEN`: the API token provided for the request specifies an invalid value |
| 400403 | `SendbirdError.ERR_INVALID_JSON_BODY` | `INVALID_JSON_REQUEST_BODY`: the request body is an invalid JSON |
| 400404 | `SendbirdError.ERR_APP_ID_NOT_VALID` | `INVALID_REQUEST_URL`: the request specifies an invalid HTTP request URL that can't be accessed (the page's server name differs from this constant's name) |
| 400500 | `SendbirdError.ERR_ACCESS_TOKEN_EMPTY` | `TOO_MANY_USER_WEBSOCKET_CONNECTIONS`: the number of the user's websocket connections exceeds the allowed amount (the page's server name differs from this constant's name) |
| 400504 | `SendbirdError.ERR_USER_CREATION_FAILED` | No public description |
| 403200 | `SendbirdError.ERR_STAT_UPLOAD_NOT_ALLOWED` | No public description |
| 409000 | `SendbirdError.ERR_CONFLICT` | No public description |
| 500901 | `SendbirdError.ERR_INTERNAL_SERVER_ERROR` | `INTERNAL_ERROR`: the server encounters an unexpected exception while trying to process the request |
| 500910 | `SendbirdError.ERR_RATE_LIMIT_EXCEEDED` | Rate limit exceeded — back off |
| 800100 | `SendbirdError.ERR_INVALID_INITIALIZATION` | SDK not initialized |
| 800101 | `SendbirdError.ERR_CONNECTION_REQUIRED` | The request failed because the device wasn't connected to the server |
| 800102 | `SendbirdError.ERR_CONNECTION_CANCELED` | The connection was canceled, or disconnect was called while the SDK was still connecting |
| 800103 | `SendbirdError.ERR_INITIALIZATION_CANCELED` | SDK initialization took longer than five seconds; the SDK stops it to avoid an ANR. Retrying initialization might work |
| 800110 | `SendbirdError.ERR_INVALID_PARAMETER` | The parameter of the method specifies an invalid value |
| 800111 | `SendbirdError.ERR_NOT_SUPPORTED` | No public description |
| 800120 | `SendbirdError.ERR_NETWORK` | The connection failed due to an unstable network or an unexpected error in the SDK's network library |
| 800121 | `SendbirdError.ERR_NETWORK_ROUTING_ERROR` | The request routing to the server failed |
| 800130 | `SendbirdError.ERR_MALFORMED_DATA` | The data format of the server response is invalid |
| 800140 | `SendbirdError.ERR_MALFORMED_ERROR_DATA` | The data format of the error message is invalid due to a problem with the request |
| 800150 | `SendbirdError.ERR_WRONG_CHANNEL_TYPE` | The channel type specified in the request is invalid |
| 800160 | `SendbirdError.ERR_MARK_AS_READ_RATE_LIMIT_EXCEEDED` | The interval between successive requests is less than a second |
| 800170 | `SendbirdError.ERR_QUERY_IN_PROGRESS` | A retrieval request for channels, messages, or users arrived while the previous retrieval request was still being processed |
| 800180 | `SendbirdError.ERR_ACK_TIMEOUT` | Server ack timed out |
| 800190 | `SendbirdError.ERR_LOGIN_TIMEOUT` | Connect/login timed out |
| 800200 | `SendbirdError.ERR_WEBSOCKET_CONNECTION_CLOSED` | The request was submitted while disconnected from the server |
| 800201 | `SendbirdError.ERR_WEBSOCKET_CONNECTION_CLOSED_AFTER_DNS_FALLBACK` | No public description |
| 800210 | `SendbirdError.ERR_WEBSOCKET_CONNECTION_FAILED` | The websocket connection to the server failed to establish |
| 800220 | `SendbirdError.ERR_REQUEST_FAILED` | The server failed to process the request due to an internal reason |
| 800221 | `SendbirdError.ERR_CONNECTION_DELAYED` | No public description |
| 800230 | `SendbirdError.ERR_FILE_UPLOAD_CANCEL_FAILED` | The request to cancel a file upload failed due to an unexpected error |
| 800240 | `SendbirdError.ERR_FILE_UPLOAD_CANCELED` | The file upload request was canceled |
| 800250 | `SendbirdError.ERR_FILE_UPLOAD_TIMEOUT` | No public description |
| 800251 | `SendbirdError.ERR_FILE_UPLOAD_TIMEOUT_BY_NETWORK` | No public description |
| 800260 | `SendbirdError.ERR_FILE_SIZE_LIMIT_EXCEEDED` | No public description |
| 800270 | `SendbirdError.ERR_UPLOAD_STAT_RETRY_COUNT_EXCEEDED` | No public description |
| 800400 | `SendbirdError.ERR_PENDING` | No public description |
| 800500 | `SendbirdError.ERR_PARSED_INVALID_AUTH_TOKEN` | No public description |
| 800501 | `SendbirdError.ERR_SESSION_KEY_REFRESH_SUCCEEDED` | No public description |
| 800502 | `SendbirdError.ERR_SESSION_KEY_REFRESH_FAILED` | No public description |
| 800600 | `SendbirdError.ERR_COLLECTION_DISPOSED` | No public description |
| 800700 | `SendbirdError.ERR_DATABASE_ERROR` | Something went wrong with the database; the SDK keeps working, but local caching is disabled |
| 800701 | `SendbirdError.ERR_DATABASE_ERROR_ENCRYPTION` | A sqlcipher problem, possibly an undeclared sqlcipher dependency or a wrong encryption key. If the password is forgotten, clear the data with `SendbirdChat.clearCachedData` |
| 900020 | `SendbirdError.ERR_NOT_A_MEMBER` | `USER_NOT_MEMBER`: the request failed because the user isn't a member of the channel |
| 900041 | `SendbirdError.ERR_USER_IS_MUTED` | `MUTED_USER_IN_CHANNEL_SEND_MESSAGE_NOT_ALLOWED`: the user is muted in the channel and isn't allowed to send the message |
| 900050 | `SendbirdError.ERR_CHANNEL_IS_FROZEN` | `CHANNEL_FROZEN`: the request failed because the channel is frozen. Operators can still send messages in a frozen channel; other members can't. The error-codes page words this as "no one can send", but the freeze page and the Chat API moderation overview both name the operator exception |
| 900060 | `SendbirdError.ERR_PROFANITY_MESSAGE_BLOCK` | `PROFANITY_MESSAGE_BLOCKED`: the request specifies a message containing a profanity word |
| 900100 | `SendbirdError.ERR_INVALID_AUTHORITY` | `BANNED_USER_SEND_MESSAGE_NOT_ALLOWED`: the user is banned from the channel and isn't allowed to send the message (the page's server name differs from this constant's name) |
| 900200 | `SendbirdError.ERR_TOO_MANY_MESSAGES` | `TOO_MANY_MESSAGES`: the number of sent messages exceeds the allowed amount |
| 900500 | `SendbirdError.ERR_CHANNEL_NOT_FOUND` | `CHANNEL_NOT_FOUND`: there is no channel to perform this operation |
| 900800 | `SendbirdError.ERR_NOT_OPERATOR` | No public description |

(source: https://sendbird.com/docs/chat/sdk/v4/android/error-codes — meanings)
(source: sendbird-common-1.0.7 (dependency of sendbird-chat-4.36.5) javap com.sendbird.android.exception.SendbirdError — codes and constant names)
(The Platform API error-codes page, https://sendbird.com/docs/chat/platform-api/v3/error-codes, was also checked for every "No public description" code; it lists none of them.)
(900050 row, operator exception: source: https://sendbird.com/docs/chat/sdk/v4/android/channel/moderating-a-channel/freeze-and-unfreeze-a-channel ; https://sendbird.com/docs/chat/platform-api/v3/moderation/moderation-overview — reviewed 2026-10-16)

## Handling tips
- Session token expired or revoked: the SDK calls `SessionHandler.onSessionTokenRequired`; answer it with a new token (see auth).
- `ERR_CONNECTION_REQUIRED`: call `SendbirdChat.connect(...)` first.
- `ERR_RATE_LIMIT_EXCEEDED`: exponential backoff.
- Compare against `e.code` on the `SendbirdException` in your callback.

## Related
- Auth/session: knowledge/curated/android/products/auth.md
- Full code reference: https://sendbird.com/docs (the bare /docs/chat/sdk/v4/<platform> index paths 404; deep pages resolve)
