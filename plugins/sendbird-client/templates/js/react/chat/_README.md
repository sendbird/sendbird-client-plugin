<!-- status: populated -->
# templates/js/react/chat

Chat init + connect, channel list, and message list on React (`@sendbird/chat`).
From sendbird.com/docs (chat v4 javascript getting-started, verified 2026-06-09)
and the shipped `@sendbird/chat@4.22.13` type declarations (verified 2026-09-29).
**Type-checked** against the real package (`tsc --strict --skipLibCheck` clean).

## Files
- `connect.tsx` — `SendbirdChat.init` + `connectUser(userId, accessToken?)`.
- `GroupChannelList.tsx` — live-updating channel list via `GroupChannelCollection`
  (`createGroupChannelCollection` / `setGroupChannelCollectionHandler` / `loadMore`).
- `GroupChannelMessages.tsx` — message list via `MessageCollection`
  (`createMessageCollection` / `initialize` / `setMessageCollectionHandler` /
  `loadPrevious`), plus reaction, typing, and read-status helpers.

## How to splice
1. `npm install @sendbird/chat`
2. Import `sb` / call `connectUser(...)` after login (`connect.tsx`).
3. For a channel list screen: `createChannelListCollection(sb)` then
   `subscribeChannelList(collection, { onAdded, onUpdated, onDeleted })`
   (`GroupChannelList.tsx`). Call `dispose()` on unmount.
4. For a message list screen: `createMessageListCollection(channel)` then
   `initializeMessageList(collection, { onCache, onApi, onAdded, onUpdated, onDeleted })`
   (`GroupChannelMessages.tsx`). Call `dispose()` on unmount.
5. App ID from env (e.g. `NEXT_PUBLIC_SENDBIRD_APP_ID`) — never hard-code; tokens are secrets.

## Variations (see knowledge/curated/js/products/chat.md, all cited)
- Open channels: `OpenChannelModule` from `@sendbird/chat/openChannel`.
- Send: `channel.sendUserMessage({ message }).onSucceeded(...)`.
- File message: `channel.sendFileMessage({ file, fileName, mimeType })`.
- Prebuilt UI: `@sendbird/uikit-react` (see uikit curated).
