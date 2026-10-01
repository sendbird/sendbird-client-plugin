<!-- status: populated -->
# templates/android/view/auth

Authentication (part of Chat) on Android: session-token connect, token refresh via
`SessionHandler`, logout. From sendbird.com/docs; import paths verified via org-wide code
search. NOT compiled in-repo (no Android/Java toolchain).

## Files
- `SessionAuth.kt` — `installSessionHandler()` / `connect(...)` / `logout()`.

## How to splice
1. Uses the Chat SDK (`com.sendbird.sdk:sendbird-chat`).
2. Call `installSessionHandler()` before `connect(...)`.
3. In `onSessionTokenRequired`, fetch a fresh token → `sessionTokenRequester.onSuccess(token)`.
4. Tokens are secrets — never hard-code or log.

## Notes (see knowledge/curated/android/products/auth.md, all cited)
- `SendbirdChat.setSessionHandler(SessionHandler)`, `SessionTokenRequester`.
- Logout: `SendbirdChat.disconnect { }`.
