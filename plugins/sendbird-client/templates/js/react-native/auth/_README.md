<!-- status: populated -->
# templates/js/react-native/auth

Authentication (part of Chat) on React Native: session-token connect, token refresh via
`SessionHandler`, logout (`@sendbird/chat`, platform-agnostic core). From sendbird.com/docs.
Type-checked against `@sendbird/chat`; full RN `tsc` not run in-repo.

## Files
- `session.ts` — `installSessionHandler(sb, refresh)` / `connect(...)` / `logout(...)`.

## How to splice
1. Uses `@sendbird/chat` (see chat template for the `sb` instance).
2. Call `installSessionHandler(sb, refresh)` before `connect(...)`.
3. Tokens are secrets — never hard-code or log.

## Notes (see knowledge/curated/js/products/auth.md, all cited)
- `import { SessionHandler } from '@sendbird/chat'`, `sb.setSessionHandler(handler)`.
