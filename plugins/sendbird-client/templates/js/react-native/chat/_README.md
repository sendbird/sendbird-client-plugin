<!-- status: populated -->
# templates/js/react-native/chat

Chat init + connect on React Native (`@sendbird/chat`, platform-agnostic core).
From sendbird.com/docs (chat v4 javascript getting-started, verified 2026-06-09).
**Type-checked** against the real package (`tsc --noEmit` clean).

## Files
- `connect.ts` — `SendbirdChat.init` + `connectUser(userId, accessToken?)`.

## How to splice
1. `npm install @sendbird/chat`
2. Import `sb` / call `connectUser(...)` after login.
3. App ID from env — never hard-code; access/session tokens are secrets.

## Variations (see knowledge/curated/js/products/chat.md, all cited)
- Open channels: add `OpenChannelModule` from `@sendbird/chat/openChannel`.
- Send: `channel.sendUserMessage({ message }).onSucceeded(...)`.
- Prebuilt UI: `@sendbird/uikit-react-native` (see uikit curated).
