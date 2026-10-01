<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: enum-diff-android -->
<!-- status: populated -->
# android — errors

> Android constant names (`SendbirdError.ERR_*`) verified via org-wide code search of public Sendbird repos (verified 2026-09-30); the 400302/400309/400310 and 800101/800102/800120 rows were also checked with `javap` against `SendbirdError` in sendbird-common 1.0.7 (a dependency of sendbird-chat 4.36.5). Interpret a numeric code with the enum shipped for the customer's platform and SDK version; the same number can have a different symbol or description on another platform. Used by `/sendbird-client:explain-error`. Do not invent codes or names.

## How errors surface
SDK callbacks return a `SendbirdException` (`com.sendbird.android.exception.SendbirdException`); its code matches the shared Sendbird error codes. Constants are exposed as `SendbirdError.ERR_*`.

## Common codes (names: SendbirdError.ERR_* verified via code search; codes: shared Sendbird codes)
| Code | Android constant | Meaning / typical cause |
|------|------------------|--------------------------|
| 400108 | `SendbirdError.ERR_NON_AUTHORIZED` | Not authorized |
| 400302 | `SendbirdError.ERR_INVALID_TOKEN` | Access/session token invalid or expired — refresh via SessionHandler |
| 400309 | `SendbirdError.ERR_SESSION_KEY_EXPIRED` | Constant name and value verified from the SDK (sendbird-common `SendbirdError`); the public error-codes page has no entry for 400309, so no meaning is documented |
| 400310 | `SendbirdError.ERR_SESSION_TOKEN_REVOKED` | Session token revoked |
| 500910 | `SendbirdError.ERR_RATE_LIMIT_EXCEEDED` | Rate limit exceeded — back off |
| 800100 | `SendbirdError.ERR_INVALID_INITIALIZATION` | SDK not initialized |
| 800101 | `SendbirdError.ERR_CONNECTION_REQUIRED` | The request failed because the device wasn't connected to the server |
| 800102 | `SendbirdError.ERR_CONNECTION_CANCELED` | The connection was canceled, or disconnect was called while the SDK was still connecting |
| 800120 | `SendbirdError.ERR_NETWORK` | The connection failed due to an unstable network or an unexpected error in the SDK's network library |
| 800180 | `SendbirdError.ERR_ACK_TIMEOUT` | Server ack timed out |
| 800190 | `SendbirdError.ERR_LOGIN_TIMEOUT` | Connect/login timed out |

(source for 400309, 800101, 800102, 800120: sendbird-common-1.0.7 (dependency of sendbird-chat-4.36.5) javap com.sendbird.android.exception.SendbirdError; https://sendbird.com/docs/chat/sdk/v4/android/error-codes)

## Handling tips
- Session token expired or revoked: the SDK calls `SessionHandler.onSessionTokenRequired`; answer it with a new token (see auth).
- `ERR_CONNECTION_REQUIRED`: call `SendbirdChat.connect(...)` first.
- `ERR_RATE_LIMIT_EXCEEDED`: exponential backoff.
- Compare against `e.code` on the `SendbirdException` in your callback.

## Related
- Auth/session: knowledge/curated/android/products/auth.md
- Full code reference: https://sendbird.com/docs (the bare /docs/chat/sdk/v4/<platform> index paths 404; deep pages resolve)
