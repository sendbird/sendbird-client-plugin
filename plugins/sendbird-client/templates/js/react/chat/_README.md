<!-- status: populated -->
# templates/js/react/chat

Chat init + connect, channel list, message list, and the most requested message features on React (`@sendbird/chat`).
From sendbird.com/docs (chat v4 javascript getting-started, verified 2026-06-09)
and the shipped `@sendbird/chat` type declarations (4.22.13 verified 2026-09-29; the feature files against 4.22.11 and 4.22.14).
**Type-checked** against the real package (`tools/templates/compile-check-js.sh`, `tsc --strict`, pinned and latest).

Sources: (source: knowledge/curated/js/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

## Files
- `connect.tsx` — `SendbirdChat.init` + `connectUser(userId, accessToken?)`.
- `GroupChannelList.tsx` — live-updating channel list via `GroupChannelCollection`
  (`createGroupChannelCollection` / `setGroupChannelCollectionHandler` / `loadMore`).
- `GroupChannelMessages.tsx` — message list via `MessageCollection`
  (`createMessageCollection` / `initialize` / `setMessageCollectionHandler` /
  `loadPrevious`), row helpers for rendering (`messageRow`, `messageKey`), `sendText`, plus
  reaction, typing, and read-status helpers.
- `PushRegistration.ts` — register and unregister FCM and APNs tokens.
- `FileMessageUpload.ts` — send a picked `File`, with an upload progress bar (`uploadFile` then `fileUrl`), cancel an upload, resend a failed file message.
- `MessageEditing.ts` — edit and delete your own messages, and hear about other members' edits and deletes.
- `UnreadCount.ts` — `useTotalUnreadCount(sb)` hook for a badge, per-channel count, mark as read.
- `TypingAndReadReceipts.ts` — `useChannelActivity(sb, channel)` hook for "… is typing" and read marks.

## How to splice
1. `npm install @sendbird/chat`
2. Import `sb` / call `connectUser(...)` after login (`connect.tsx`).
3. For a channel list screen: `createChannelListCollection(sb)` then
   `subscribeChannelList(collection, { onAdded, onUpdated, onDeleted })`
   (`GroupChannelList.tsx`). Call `dispose()` on unmount.
4. For a message list screen: `createMessageListCollection(channel)` then
   `initializeMessageList(collection, { onCache, onApi, onAdded, onUpdated, onDeleted })`
   (`GroupChannelMessages.tsx`). `onCache` / `onApi` already get the page oldest first; set the
   list to it. For `onAdded`, `onUpdated`, and `loadOlderMessages` results, update the list with
   `mergeMessages(current, messages)`. Never render a callback array as it arrives: its order is
   not documented. Call `dispose()` on unmount.
   Render each row from `messageRow(message, sb.currentUser?.userId)`: it gives `key`, `text`,
   `senderName`, `mine`, and `isAdmin`, read through the declared types. Do not write
   `'reqId' in message`: `reqId` is not on `BaseMessage`, so that check leaves it typed `unknown`,
   and a `key` built from it fails the type check (use `messageKey` or `requestIdOf`). `sender` is
   on user, file, and multiple-files messages only, so read it after `message.isUserMessage()`,
   `isFileMessage()`, or `isMultipleFilesMessage()`; `message.message` (the text) is on every message.
   To send, call `sendText(channel, text, { onPending, onSucceeded, onFailed })` and merge each
   message into the list with `mergeMessages`; `onFailed` can get `null` instead of a message.
5. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; tokens are secrets.

The feature files below assume a connected `sb` and a loaded group channel. Copy only the files the app needs.

### Send an image or file (`FileMessageUpload.ts`)
1. From `<input type="file" onChange>`, take `event.target.files[0]`.
2. With a progress bar: `sendFileWithProgress(channel, file, { onProgress, onUploadStarted, onPending, onSucceeded, onFailed })`;
   keep the request ID from `onUploadStarted` for `cancelUpload(channel, requestId)`. Without one: `sendFile(channel, file, callbacks)`.
3. Show the pending message from `onPending`; on `onFailed` keep the failed message and offer Retry:
   `resendFailedFile(channel, failed, callbacks, file)`.

### Edit and delete messages (`MessageEditing.ts`)
1. In the message menu, show Edit and Delete only when `isMine(sb, message)`.
2. `await editMessage(channel, message, text)` returns the updated message; `await deleteMessage(channel, message)` removes it.
3. On a `GroupChannelMessages.tsx` screen, other members' changes already arrive through `onUpdated` / `onDeleted`.
   Otherwise: `useEffect(() => watchMessageChanges(sb, channel.url, { onUpdated, onDeleted }), [channel.url])`.

### Unread counts (`UnreadCount.ts`)
1. `const { total, refresh } = useTotalUnreadCount(isConnected ? sb : null)` in the app shell; show `total` on the badge.
2. Per row: `channelUnreadCount(channel)`. When a conversation opens: `markChannelReadAndRefresh(channel, refresh)`.

### Typing indicator and read receipts (`TypingAndReadReceipts.ts`)
1. `const { typingNames, readReceiptsVersion } = useChannelActivity(sb, channel)` in the conversation component (it marks the channel read on mount).
2. In the input's `onChange` call `onDraftChange(channel, value)`; after sending call `onDraftChange(channel, '')`.
3. Show "… is typing" from `typingNames`. For your own messages, show a read mark when
   `unreadMemberCount(channel, message) === 0`; `readReceiptsVersion` re-renders the list when someone reads.

## Variations (see knowledge/curated/js/products/chat.md, all cited)
- Open channels: `OpenChannelModule` from `@sendbird/chat/openChannel`.
- Send: `channel.sendUserMessage({ message }).onSucceeded(...)`.
- Prebuilt UI: `@sendbird/uikit-react` (see uikit curated).
