<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android auth

> Auth is part of Chat, not a standalone product. Verified against sendbird.com/docs (Chat v4 Android authentication, verified 2026-09-30); import paths verified via org-wide code search. The "Session token expiry" snippet was checked with `javap` against the sendbird-chat 4.36.5 AAR and compiled against chat 4.36.5 in a copy of the `tests/android-compile` harness; the other snippets were not compiled in-repo — flagged. Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication

## Overview
A user authenticates by connecting with a user ID and (for secured apps) a session/access token. A `SessionHandler` refreshes the token on expiry; disconnect on logout.

## Connect (session token)
```kotlin
SendbirdChat.connect(USER_ID, AUTH_TOKEN) { user, e ->
    if (user != null) { /* connected (online if e == null, else offline cache) */ }
}
```
(source: docs chat v4 android authentication)

## Session token expiry

Set the `SessionHandler` before `connect`. A session lasts ten minutes and the SDK refreshes it internally while the session token is active; `SessionHandler.onSessionTokenRequired` fires only when the token has expired or been revoked. Answer with `sessionTokenRequester.onSuccess(newToken)` or `onFail()` within the refresh timeout (60–1800 s, default 60, set via `SendbirdChat.Options.setSessionTokenRefreshTimeout`); if neither is called in time, the socket disconnects and you must call `SendbirdChat.connect(USER_ID, AUTH_TOKEN)` again. On `connect`, error codes 400300, 400301, 400302 (`ERR_INVALID_TOKEN`) and 400310 (`ERR_SESSION_TOKEN_REVOKED`) make the SDK clear locally cached user data.

```kotlin
SendbirdChat.Options.setSessionTokenRefreshTimeout(60) // 60..1800 seconds
SendbirdChat.setSessionHandler(object : SessionHandler() {
    override fun onSessionTokenRequired(sessionTokenRequester: SessionTokenRequester) {
        fetchTokenFromServer { token ->
            if (token != null) sessionTokenRequester.onSuccess(token) else sessionTokenRequester.onFail()
        }
    }
    override fun onSessionClosed() { /* route to login */ }
    override fun onSessionRefreshed() { }
    override fun onSessionError(sendbirdException: SendbirdException) { }
})
```

(source: sendbird-chat-4.36.5.aar javap com.sendbird.android.handler.SessionHandler / SessionTokenRequester; sendbird-common-1.0.7 javap com.sendbird.android.exception.SendbirdError; https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication)
(source: docs chat v4 android authentication — `SessionHandler` abstract class, `SessionTokenRequester`, `SendbirdChat.setSessionHandler(...)`)

## Reauth / multi-device
- Reauth: on `onSessionClosed()`, re-issue a token from your server and reconnect.
- Multi-device: the same `userId` may connect from multiple devices simultaneously.

## Logout
```kotlin
SendbirdChat.disconnect {
    // disconnected; locally saved data cleared
}
```
(source: docs chat v4 android authentication)

## Pitfalls
- Call `setSessionHandler(...)` before `connect`.
- Tokens are secrets — never hard-code or log; issue from your server.

## Related
- Underlying Chat: knowledge/curated/android/products/chat.md
