<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-10-10 -->
<!-- verification-method: enum-diff-js -->
<!-- status: populated -->
# js — errors

> Error codes + names read verbatim from `@sendbird/chat`'s shipped `SendbirdErrorCode` enum (`lib/__definition.d.ts`), verified 2026-10-10. Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes.

## How errors surface

Rejected promises / callbacks return a `SendbirdError` with a numeric `code` field matching `SendbirdErrorCode`.

**Calls errors (1800xxx) are a separate table.** Codes in the 1800xxx range come from the Calls SDK, not Chat, and are not in the table below. Look them up in the "Error codes (1800xxx range)" section of knowledge/curated/js/products/calls.md.

## All codes (source: @sendbird/chat SendbirdErrorCode enum)

Every member of the shipped enum is listed. The enum members carry no JSDoc. Meanings of the rows added on 2026-10-10 are quoted from the client-side and server-side tables on the JavaScript error codes page (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes). Where that page names the code differently from the enum, the row gives the page's name. "No public description" means neither that page nor the Platform API error codes page (source: https://sendbird.com/docs/chat/platform-api/v3/error-codes) describes the code; the code and symbol are still read from the enum.

| Code | JS symbol | Meaning / typical cause |
|------|-----------|--------------------------|
| 400108 | `NON_AUTHORIZED` | Not authorized |
| 400105 | `INVALID_REQUIRED_FORM_VALUE` | Required value missing/invalid |
| 400111 | `INVALID_TOKEN` | The request specifies an invalid value. (Docs name: `INVALID_VALUE`.) Despite the enum member's name, the JavaScript, iOS, and Android error-codes pages and the Platform API error-codes page all describe 400111 as an invalid parameter value, not a token error (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes ; https://sendbird.com/docs/chat/platform-api/v3/error-codes — reviewed 2026-10-16) |
| 400201 | `NOT_FOUND_IN_DATABASE` | Resource not found |
| 400202 | `ERR_DUPLICATED_DATA` | Duplicated data |
| 400300 | `USER_AUTH_DEACTIVATED` | User deactivated |
| 400301 | `USER_AUTH_DELETED_OR_NOT_FOUND` | User deleted/not found |
| 400302 | `SESSION_TOKEN_EXPIRED` | The access token provided for the request specifies an invalid value. (Docs name: `INVALID_ACCESS_TOKEN`.) Despite the enum member's name, the JavaScript, iOS, and Android error-codes pages describe 400302 as an invalid access token, not an expired one (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes — reviewed 2026-10-16) |
| 400304 | `APPLICATION_NOT_FOUND` | App ID not found |
| 400309 | `SESSION_KEY_EXPIRED` | Session key expired |
| 400310 | `SESSION_REVOKED` | Session revoked |
| 400312 | `INVALID_SESSION_TYPE` | No public description |
| 400313 | `INVALID_AUTH_FOR_SERVICE` | No public description |
| 400940 | `NOT_SUPPORTED_PINNED_MESSAGE_IN_REVIEW_MESSAGE` | No public description |
| 403200 | `STAT_UPLOAD_NOT_ALLOWED` | No public description |
| 500901 | `INTERNAL_SERVER_ERROR` | Internal server error |
| 500910 | `RATE_LIMIT_EXCEEDED` | Rate limit exceeded — back off |
| 700000 | `DEBUG_MODE_REQUIRED` | No public description |
| 700100 | `LOST_INSTANCE` | No public description |
| 700102 | `CONNECTION_RENEW` | No public description |
| 700200 | `INVALID_CONNECTION_STATE_TRANSITION` | No public description |
| 700700 | `INVALID_COMMAND` | No public description |
| 700800 | `XMLHTTPREQUEST_NOT_SUPPORTED` | No public description |
| 770000 | `UNKNOWN_ERROR` | No public description |
| 800100 | `INVALID_INITIALIZATION` | SDK not initialized |
| 800101 | `CONNECTION_REQUIRED` | Must connect first |
| 800102 | `CONNECTION_CANCELED` | Connect was canceled, or disconnect was called while connecting |
| 800110 | `INVALID_PARAMETER` | Invalid parameter (client-side) |
| 800111 | `NOT_SUPPORTED_ERROR` | No public description |
| 800120 | `NETWORK_ERROR` | Network error |
| 800121 | `NETWORK_ROUTING_ERROR` | Request routing to the server failed |
| 800130 | `MALFORMED_DATA` | The data format of the server response is invalid. |
| 800140 | `MALFORMED_ERROR_DATA` | The data format of the error message is invalid due to the problem with the request. |
| 800150 | `WRONG_CHANNEL_TYPE` | The specified channel type in the request is invalid. |
| 800160 | `MARK_AS_READ_RATE_LIMIT_EXCEEDED` | markAsRead called too often |
| 800170 | `QUERY_IN_PROGRESS` | A retrieval request is arriving while the server is still processing the previous retrieval request for channels, messages, or users, and in preparation to send the response. |
| 800190 | `LOGIN_TIMEOUT` | Connect/login timed out |
| 800180 | `ACK_TIMEOUT` | Server ack timed out |
| 800200 | `WEBSOCKET_CONNECTION_CLOSED` | Request sent while disconnected |
| 800210 | `WEBSOCKET_CONNECTION_FAILED` | WebSocket could not be established |
| 800220 | `REQUEST_FAILED` | The server failed to process the request due to an internal reason. |
| 800221 | `DELAYED_CONNECTING` | No public description |
| 800230 | `FILE_UPLOAD_CANCEL_FAILED` | The request to cancel file upload failed due to an unexpected error. |
| 800240 | `REQUEST_CANCELED` | The server failed to process the request due to the cancellation. (The docs page spells it `REQUEST_CANCELLED`.) |
| 800250 | `REQUEST_DUPLICATED` | No public description |
| 800260 | `FILE_SIZE_LIMIT_EXCEEDED` | No public description |
| 800270 | `ERR_UPLOAD_STAT_RETRY_COUNT_EXCEEDED` | No public description |
| 800500 | `SESSION_TOKEN_REQUEST_FAILED` | No public description |
| 800501 | `SESSION_TOKEN_REFRESHED` | No public description |
| 800502 | `SESSION_TOKEN_REFRESH_FAILED` | No public description |
| 800600 | `COLLECTION_DISPOSED` | No public description |
| 800700 | `DATABASE_ERROR` | No public description |
| 900021 | `USER_DEACTIVATED` | The request failed because the user is deactivated in the service. |
| 900050 | `CHANNEL_IS_FROZEN` | The request failed because the channel is frozen. (Docs name: `CHANNEL_FROZEN`.) Operators can still send messages in a frozen channel; other members can't. The error-codes page words this as "no one can send", but the freeze page and the Chat API moderation overview both name the operator exception (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/moderating-a-channel/freeze-and-unfreeze-a-channel ; https://sendbird.com/docs/chat/platform-api/v3/moderation/moderation-overview — reviewed 2026-10-16) |
| 900081 | `RECEIVER_USER_DEACTIVATED` | The request failed because the user is trying to send the message to the deactivated user in a 1-to-1 distinct channel. (Docs name: `DEACTIVATED_USER_RECEIVE_MESSAGE_NOT_ALLOWED`.) |
| 900200 | `UNKNOWN_SERVER_ERROR` | No public description of this symbol. The server-side table on the JavaScript error codes page lists 900200 under a different name, `TOO_MANY_MESSAGES` ("The number of the sent messages exceeds the allowed amount."). |
| 901500 | `NOT_SUPPORTED_FEATURE_IN_IN_REVIEW_MESSAGE` | No public description |

## Handling tips

- `SESSION_TOKEN_EXPIRED` (400302) / `SESSION_KEY_EXPIRED` (400309) / `SESSION_REVOKED` (400310): handle through `SessionHandler` (see auth). With local caching enabled, 400300, 400301, 400302, and 400310 on `connect()` mean you should clear the user's cached data before reconnecting. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4844-4847 ; https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication)
- `CONNECTION_REQUIRED` (800101): `await sb.connect(...)` first.
- `RATE_LIMIT_EXCEEDED` (500910): exponential backoff. Plan limits are not stated here; point to the pricing page and the dashboard (knowledge/curated/common/pricing-quotas.md).

## Connection failures

- `NETWORK_ERROR` (800120) means the request failed because of an unstable network or an unexpected error in the SDK network layer; it is a client-side code, not a server rejection. `CONNECTION_REQUIRED` (800101) and `WEBSOCKET_CONNECTION_CLOSED` (800200) mean the call was made while not connected, so wait for `ConnectionHandler.onReconnectSucceeded` rather than retrying in a tight loop. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4866-4880)
- Domain restrictions surface as server codes `DOMAIN_NOT_ALLOWED` (400307) or `RESTRICTED_DOMAIN_BLOCKED` (900065). 400307 has no `SendbirdErrorCode` member in the JS SDK, so compare the numeric `error.code`. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes)
- The JS SDK has no DNS-fallback option; `SendbirdChatParams` only exposes `customApiHost` / `customWebSocketHost` for host overrides. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4805-4823)

## Related

- Auth/session: knowledge/curated/js/products/auth.md
- Full code reference: https://sendbird.com/docs (the bare /docs/chat/sdk/v4/<platform> index paths 404; deep pages resolve)
