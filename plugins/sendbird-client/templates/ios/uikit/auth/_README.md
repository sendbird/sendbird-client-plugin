<!-- status: populated -->
# templates/ios/uikit/auth

Authentication (part of Chat) on iOS: session-token connect, token refresh via
`SessionDelegate`, logout. From sendbird.com/docs + `SendbirdChatSDK.swiftinterface`
(verified 2026-06-10). **Build-verified** against `SendbirdChatSDK` (xcodebuild BUILD SUCCEEDED).

## Files
- `SessionAuth.swift` — `start()` (register delegate) / `connect(...)` / `logout()` + `SessionDelegate`.

## How to splice
1. Uses the Chat SPM package (`SendbirdChatSDK`).
2. Call `start()` to register the delegate + refresh timeout before `connect(...)`.
3. Implement `sessionTokenDidRequire` to fetch a fresh token from your server.
4. Tokens are secrets — never hard-code or log.

## Notes (see knowledge/curated/ios/products/auth.md, all cited)
- `SendbirdChat.setSessionDelegate(_:)`, `SendbirdChatOptions.setSessionTokenRefreshTimeout(_:)`.
- Logout: `SendbirdChat.disconnect` (full) / `disconnectWebSocket` (keep cache).
