<!-- status: populated -->
# templates/js/react/auth

Authentication (part of Chat) on React: session-token connect, token refresh via
`SessionHandler`, logout. From sendbird.com/docs. **Type-checked** against `@sendbird/chat`
(`tsc --noEmit` clean) — `SessionHandler` import + callbacks + connect/setSessionHandler/disconnect.

## Files
- `session.ts` — `installSessionHandler(sb, refresh)` / `connect(...)` / `logout(...)`.

## How to splice
1. Uses `@sendbird/chat` (see chat template for the `sb` instance).
2. Call `installSessionHandler(sb, refresh)` before `connect(...)`.
3. `refresh` fetches a fresh token from your server.
4. Tokens are secrets — never hard-code or log.

## Notes (see knowledge/curated/js/products/auth.md, all cited)
- `import { SessionHandler } from '@sendbird/chat'`, `sb.setSessionHandler(handler)`.
- Logout: `sb.disconnect()` / `sb.disconnectWebSocket()`.
