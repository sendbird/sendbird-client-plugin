<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: enum-diff-js -->
<!-- status: populated -->
# js — errors

> Error codes + names read verbatim from `@sendbird/chat`'s shipped `SendbirdErrorCode` enum (`lib/__definition.d.ts`), verified 2026-09-30. Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes.

## How errors surface

Rejected promises / callbacks return a `SendbirdError` with a numeric `code` field matching `SendbirdErrorCode`.

## Common codes (source: @sendbird/chat SendbirdErrorCode enum)

| Code | JS symbol | Meaning / typical cause |
|------|-----------|--------------------------|
| 400108 | `NON_AUTHORIZED` | Not authorized |
| 400105 | `INVALID_REQUIRED_FORM_VALUE` | Required value missing/invalid |
| 400111 | `INVALID_TOKEN` | Invalid token |
| 400201 | `NOT_FOUND_IN_DATABASE` | Resource not found |
| 400202 | `ERR_DUPLICATED_DATA` | Duplicated data |
| 400300 | `USER_AUTH_DEACTIVATED` | User deactivated |
| 400301 | `USER_AUTH_DELETED_OR_NOT_FOUND` | User deleted/not found |
| 400302 | `SESSION_TOKEN_EXPIRED` | Session/access token expired — refresh via SessionHandler |
| 400304 | `APPLICATION_NOT_FOUND` | App ID not found |
| 400309 | `SESSION_KEY_EXPIRED` | Session key expired |
| 400310 | `SESSION_REVOKED` | Session revoked |
| 500901 | `INTERNAL_SERVER_ERROR` | Internal server error |
| 500910 | `RATE_LIMIT_EXCEEDED` | Rate limit exceeded — back off |
| 800100 | `INVALID_INITIALIZATION` | SDK not initialized |
| 800101 | `CONNECTION_REQUIRED` | Must connect first |
| 800102 | `CONNECTION_CANCELED` | Connect was canceled, or disconnect was called while connecting |
| 800110 | `INVALID_PARAMETER` | Invalid parameter (client-side) |
| 800120 | `NETWORK_ERROR` | Network error |
| 800121 | `NETWORK_ROUTING_ERROR` | Request routing to the server failed |
| 800160 | `MARK_AS_READ_RATE_LIMIT_EXCEEDED` | markAsRead called too often |
| 800190 | `LOGIN_TIMEOUT` | Connect/login timed out |
| 800180 | `ACK_TIMEOUT` | Server ack timed out |
| 800200 | `WEBSOCKET_CONNECTION_CLOSED` | Request sent while disconnected |
| 800210 | `WEBSOCKET_CONNECTION_FAILED` | WebSocket could not be established |

## Handling tips

- `SESSION_TOKEN_EXPIRED` (400302) / `SESSION_KEY_EXPIRED` (400309) / `SESSION_REVOKED` (400310): handle through `SessionHandler` (see auth). With local caching enabled, 400300, 400301, 400302, and 400310 on `connect()` mean you should clear the user's cached data before reconnecting. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4844-4847 ; https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication)
- `CONNECTION_REQUIRED` (800101): `await sb.connect(...)` first.
- `RATE_LIMIT_EXCEEDED` (500910): exponential backoff.

## Connection failures

- `NETWORK_ERROR` (800120) means the request failed because of an unstable network or an unexpected error in the SDK network layer; it is a client-side code, not a server rejection. `CONNECTION_REQUIRED` (800101) and `WEBSOCKET_CONNECTION_CLOSED` (800200) mean the call was made while not connected, so wait for `ConnectionHandler.onReconnectSucceeded` rather than retrying in a tight loop. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4866-4880)
- Domain restrictions surface as server codes `DOMAIN_NOT_ALLOWED` (400307) or `RESTRICTED_DOMAIN_BLOCKED` (900065). 400307 has no `SendbirdErrorCode` member in the JS SDK, so compare the numeric `error.code`. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/error-codes)
- The JS SDK has no DNS-fallback option; `SendbirdChatParams` only exposes `customApiHost` / `customWebSocketHost` for host overrides. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4805-4823)

## Related

- Auth/session: knowledge/curated/js/products/auth.md
- Full code reference: https://sendbird.com/docs (the bare /docs/chat/sdk/v4/<platform> index paths 404; deep pages resolve)
