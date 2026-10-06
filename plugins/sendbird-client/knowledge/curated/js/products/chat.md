<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- status: populated -->
# js chat

> Verified against sendbird.com/docs (Chat SDK v4 JavaScript getting-started, verified 2026-06-09) and `@sendbird/chat`. init + connect type-checked against the package (see templates/js/react/chat/connect.tsx). Channel list, message list, reactions, typing, read status, and handler sections below verified against the shipped `@sendbird/chat@4.22.13` type declarations (`lib/__definition.d.ts`, verified 2026-09-29). Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/send-first-message

## Overview
Sendbird Chat is the foundation product (auth/session live here). The core `@sendbird/chat` package is platform-agnostic — the same init/connect/message APIs work in React (web) and React Native. Initialize once, connect a user, operate on channels.

## Install
```bash
npm install @sendbird/chat
```

## Initialize (once) + modules
```ts
import SendbirdChat from '@sendbird/chat';
import { GroupChannelModule } from '@sendbird/chat/groupChannel';

const sb = SendbirdChat.init({
  appId: APP_ID,
  modules: [new GroupChannelModule()],
});
```
Add `OpenChannelModule` from `@sendbird/chat/openChannel` for open channels. (source: sendbird.com/docs chat v4 javascript getting-started)

## Connect a user (auth)
```ts
const user = await sb.connect(USER_ID);            // or sb.connect(USER_ID, ACCESS_TOKEN)
```
Pass an access/session token as the second arg for authenticated apps — see `knowledge/curated/js/products/auth.md`. (source: sendbird.com/docs chat v4 javascript getting-started)

## Create and list group channels
```ts
// Create
const channel = await sb.groupChannel.createChannel({
  invitedUserIds: [otherUserId],
  isDistinct: true,          // reuse the existing 1:1 channel instead of creating a duplicate
});
```
`GroupChannelCreateParams` also takes `channelUrl`, `coverUrl` / `coverImage`, `isSuper`, `name`, `customType`, `data`, `operatorUserIds`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:5525 `GroupChannelCreateParams`, `GroupChannelModule.createChannel` :6303)

For a live-updating channel list (the common case for a channel-list screen), use a collection instead of a one-shot query:
```ts
import { GroupChannelFilter, GroupChannelListOrder } from '@sendbird/chat/groupChannel';

const collection = sb.groupChannel.createGroupChannelCollection({
  filter: new GroupChannelFilter(),   // e.g. filter.includeEmpty = true
  order: GroupChannelListOrder.LATEST_LAST_MESSAGE,
});

collection.setGroupChannelCollectionHandler({
  onChannelsAdded: (context, channels) => { /* prepend/merge into UI state */ },
  onChannelsUpdated: (context, channels) => { /* re-render changed rows */ },
  onChannelsDeleted: (context, channelUrls) => { /* remove rows */ },
});

const channels = await collection.loadMore();   // first page; call again to paginate
// collection.dispose() when the screen unmounts
```
`createGroupChannelCollection(params?: GroupChannelCollectionParams)` is on `GroupChannelModule`; `setGroupChannelCollectionHandler(handler)` and `loadMore(): Promise<GroupChannel[]>` are on the returned `BaseChannelCollection`, along with `hasMore` and event fields `onChannelsAdded` / `onChannelsUpdated` / `onChannelsDeleted`. `dispose()` is declared on `GroupChannelCollection` itself. A one-shot alternative exists as `sb.groupChannel.createMyGroupChannelListQuery(params)` (returns a `GroupChannelListQuery`), and `createPublicGroupChannelListQuery(params)` lists channels the current user hasn't joined yet. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:6156 `createGroupChannelCollection`, :6161 `createMyGroupChannelListQuery`, :6175 `createPublicGroupChannelListQuery`, :5338-5357 `BaseChannelCollection` incl. `setGroupChannelCollectionHandler`/`loadMore`/`hasMore`, :5502-5506 `GroupChannelCollection.dispose`, :5374-5378 `onChannelsAdded/Updated/Deleted`, :5918 `GroupChannelListOrder`)

## Send a message
```ts
const params = { message: TEXT_MESSAGE };          // UserMessageCreateParams
channel.sendUserMessage(params)
  .onPending((m) => {})
  .onFailed((err, m) => {})
  .onSucceeded((m) => {});
```
`channel` from `sb.groupChannel.createChannel(params)` (group) or the open-channel API. (source: sendbird.com/docs chat v4 javascript getting-started)

### Send a file message
```ts
channel.sendFileMessage({ file, fileName: file.name, mimeType: file.type })
  .onSucceeded((m) => {});
```
`FileMessageCreateParams` accepts `file` (or `fileUrl` for a pre-uploaded file), `fileName`, `fileSize`, `mimeType`, `thumbnailSizes`, `message`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:1790 `FileMessageCreateParams`, `BaseChannel.sendFileMessage` :472)

## Update and delete a message
```ts
const updated = await channel.updateUserMessage(message.messageId, { message: 'Edited text' });
// replace the old message in your list with `updated`

await channel.deleteMessage(message);
```
- File messages: `channel.updateFileMessage(messageId, params)` with `FileMessageUpdateParams`.
- Other members are told through the channel handler: `onMessageUpdated(channel, message)` and `onMessageDeleted(channel, messageId)`.
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `BaseChannel` line 169 — `updateUserMessage(messageId, params): Promise<UserMessage>` 454, `updateFileMessage` 510, `deleteMessage(message): Promise<void>` 545; `UserMessageUpdateParams.message` 5306-5308; `BaseMessage.messageId` 853; `BaseChannelHandlerParams` 5393 — `onMessageUpdated` 5428, `onMessageDeleted` 5430 — verified 2026-10-05)
- A user can update or delete messages they sent; channel operators can update or delete any message in the channel. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/managing-a-message/update-a-message, https://sendbird.com/docs/chat/sdk/v4/javascript/message/managing-a-message/delete-a-message — reviewed 2026-10-05)

## List and receive messages
For a message list screen, use a message collection (handles both the initial page and live updates):
```ts
const collection = channel.createMessageCollection({
  filter: new MessageFilter(),
  startingPoint: Date.now(),
  limit: 30,
});

collection.initialize(MessageCollectionInitPolicy.CACHE_AND_REPLACE_BY_API)
  .onCacheResult((err, messages) => { /* render cached messages immediately */ })
  .onApiResult((err, messages) => { /* replace with the server's authoritative page */ });

collection.setMessageCollectionHandler({
  onMessagesAdded: (context, channel, messages) => { /* append incoming/sent messages */ },
  onMessagesUpdated: (context, channel, messages) => { /* e.g. a pending message resolved */ },
  onMessagesDeleted: (context, channel, messageIds, messages) => { /* remove rows */ },
});

// Pagination, driven by the collection's own cursors:
if (collection.hasPrevious) await collection.loadPrevious();
if (collection.hasNext) await collection.loadNext();
// collection.dispose() when the screen unmounts
```
`channel.createMessageCollection(params?: MessageCollectionParams)`, `.initialize(policy)` returning `.onCacheResult(handler)` / `.onApiResult(handler)`, `.setMessageCollectionHandler(handler)`, `.hasPrevious` / `.hasNext`, `.loadPrevious()` / `.loadNext()` are all on `MessageCollection` (`GroupChannel.createMessageCollection` :1992). `onMessagesDeleted` takes a 4th `messages` arg alongside the (v4.3.1-deprecated) `messageIds`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:1992, :2559-2610 `MessageCollection`/`MessageCollectionInitHandler`, :963-983 `loadPrevious`/`loadNext`/`hasPrevious`/`hasNext`, :1026-1048 `onMessagesAdded`/`onMessagesUpdated`/`onMessagesDeleted`)

## Reactions
```ts
await channel.addReaction(message, ':+1:');     // key = an emoji key configured on the app
await channel.deleteReaction(message, ':+1:');
```
Both are on `BaseChannel`, so they work for group and open channels identically; each returns a `ReactionEvent`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:169 `BaseChannel`, :552 `addReaction`, :559 `deleteReaction`)

## Typing indicator (group channels)
```ts
await channel.startTyping();
// ...user stops typing, or after your own debounce...
await channel.endTyping();
```
Handle the incoming signal in a channel handler with `onTypingStatusUpdated?: (channel: GroupChannel) => void`; read who's typing from `channel.getTypingUsers()`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:1872 `GroupChannel`, :2138 `startTyping`, :2142 `endTyping`, :5902 `onTypingStatusUpdated`)

## Read status
```ts
await channel.markAsRead();                 // this channel only
await sb.groupChannel.markAsReadAll();       // every joined group channel
```
`markAsRead()` is on `GroupChannel`; `markAsReadAll()` / `markAsReadWithChannelUrls(urls)` are on the `GroupChannelModule` (`sb.groupChannel`). (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:2129 `markAsRead`, :6332 `markAsReadAll`, :6337 `markAsReadWithChannelUrls`)

## Unread counts
```ts
import { UserEventHandler } from '@sendbird/chat';

// one channel
const unread: number = channel.unreadMessageCount;

// every group channel the user joined
const total = await sb.groupChannel.getTotalUnreadMessageCount();

// live updates: register once after connect
sb.addUserEventHandler('unread-badge', new UserEventHandler({
  onTotalUnreadMessageCountChanged: (counts) => { /* refresh badge */ },
}));
```
- Filters: `getTotalUnreadMessageCount(params?: TotalUnreadMessageCountParams)` (custom types, super-channel type). `channel.markAsRead()` (see Read status) resets a channel's count.
- The per-custom-type counts in this event (`countByCustomTypes`) are turned off by default; the app owner must contact Sendbird to enable them. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler — reviewed 2026-10-06)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannel` 1872 — `unreadMessageCount` 1903; `GroupChannelModule` 6149 — `getTotalUnreadMessageCount(params?)` 6275; `SendbirdChat` 4230 — `addUserEventHandler(key, handler)` 4414; `UserEventHandler` 5239, `UserEventHandlerParams` 5243 — `onTotalUnreadMessageCountChanged` 5249 — verified 2026-10-05)
- The total counts unread messages in all group channels the user joined; it can be filtered by channel custom type or super-channel type. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/retrieving-unread-counts-in-a-group-channel/unread-messages-in-all-channels — reviewed 2026-10-05)

## Handle incoming events without a collection
For events outside an active collection (e.g. a badge count on another screen), register a channel handler:
```ts
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';

sb.groupChannel.addGroupChannelHandler('UNIQUE_HANDLER_ID', new GroupChannelHandler({
  onMessageReceived: (channel, message) => {},
  onChannelChanged: (channel) => {},
}));
// sb.groupChannel.removeGroupChannelHandler('UNIQUE_HANDLER_ID') on cleanup
```
`GroupChannelHandler` is exported from the `@sendbird/chat/groupChannel` subpath. Add/remove exactly once per mounted screen — a handler added without a matching remove leaks. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:6187 `addGroupChannelHandler`, :6193 `removeGroupChannelHandler`, :5863 `GroupChannelHandler`, :5426 `onMessageReceived`, :5403 `onChannelChanged`; package export confirmed in `groupChannel.d.ts`)

## React vs React Native
- The core SDK is identical; only the surrounding app differs. Templates: `templates/js/react/chat/`, `templates/js/react-native/chat/`.
- For full prebuilt UI use Sendbird UIKit (`@sendbird/uikit-react` / `@sendbird/uikit-react-native`) — see `knowledge/curated/js/products/uikit.md`.

## Pitfalls
- Initialize once and reuse the returned `sb` instance; do not re-init per render/component.
- App ID read from env (e.g. `process.env.NEXT_PUBLIC_SENDBIRD_APP_ID`); access/session tokens are secrets — never hard-code or log.
- Every collection (`GroupChannelCollection`, `MessageCollection`) and every `addGroupChannelHandler` call must be paired with `dispose()` / `removeGroupChannelHandler()` when the owning screen unmounts, or the SDK keeps delivering events to a dead view.
- In strict TypeScript, `onChannelsAdded`/`onChannelsUpdated` type their `channels` param as `BaseChannel[]`, not `GroupChannel[]`, even inside a `GroupChannelCollection` — cast (it is always safe here) rather than fighting the type.
- `collection.loadMore()` / `loadPrevious()` / `loadNext()` reject if called again while a previous call for the same direction is still in flight — gate pagination on your own loading flag.

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/send-first-message
- Auth/session: knowledge/curated/js/products/auth.md
- Errors: knowledge/curated/js/cross-cutting/errors.md
