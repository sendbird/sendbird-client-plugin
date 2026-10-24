<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- status: populated -->
# js chat

> Verified against sendbird.com/docs (Chat SDK v4 JavaScript getting-started, verified 2026-06-09) and `@sendbird/chat`. init + connect type-checked against the package (see templates/js/react/chat/connect.tsx). Channel list, message list, reactions, typing, read status, and handler sections below verified against the shipped `@sendbird/chat@4.22.13` type declarations (`lib/__definition.d.ts`, verified 2026-09-29). The connect-ordering, local caching, thread, admin message, metadata, profile, and hide/archive sections were checked on 2026-10-11 against the same `@sendbird/chat@4.22.13` declarations and the linked Chat v4 JavaScript docs pages. Cite each symbol; do not add API from memory.
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

## Import paths: which entry point exports which name
`@sendbird/chat` has one entry point per module, and each name is exported from exactly one of them. The same paths apply to React and React Native.

| Import from | Names it exports (the common ones) |
|---|---|
| `@sendbird/chat` | the default export `SendbirdChat`; `BaseChannel`, `ConnectionHandler`, `ConnectionState`, `SessionHandler`, `UserEventHandler`, `User`, `SendbirdError`, `SendbirdErrorCode`, `LocalCacheConfig`, `CachedDataClearOrder`, `Role`, `PushTokenType`, `LogLevel` |
| `@sendbird/chat/groupChannel` | `GroupChannelModule`, `SendbirdGroupChat`, `GroupChannel`, `GroupChannelHandler`, `GroupChannelCollection`, `GroupChannelFilter`, `GroupChannelListOrder`, `GroupChannelCreateParams`, `MessageCollection`, `MessageFilter`, `MessageCollectionInitPolicy`, `Member`, `HiddenChannelFilter`, `HiddenState`, `MutedState` |
| `@sendbird/chat/openChannel` | `OpenChannelModule`, `SendbirdOpenChat`, `OpenChannel`, `OpenChannelHandler` |
| `@sendbird/chat/message` | `BaseMessage`, `UserMessage`, `FileMessage`, `AdminMessage`, `UserMessageCreateParams`, `FileMessageCreateParams`, `UserMessageUpdateParams`, `MessageType`, `SendingStatus`, `ReactionEvent` |

The package also has `@sendbird/chat/poll`, `@sendbird/chat/feedChannel`, `@sendbird/chat/aiAgent`, and `@sendbird/chat/node`. `SendbirdChat` is only a default export; there is no named `SendbirdChat` export.

```ts
import SendbirdChat, { ConnectionState } from '@sendbird/chat';
import { GroupChannelModule, type GroupChannel, type SendbirdGroupChat } from '@sendbird/chat/groupChannel';
import type { UserMessage } from '@sendbird/chat/message';

const sb = SendbirdChat.init({ appId: APP_ID, modules: [new GroupChannelModule()] }) as SendbirdGroupChat;
```
- Rule: type the instance by the modules you pass, as above (`as SendbirdGroupChat` for `[new GroupChannelModule()]`). `init` is generic over its `modules` (`static init<Modules extends Module[]>(params: SendbirdChatParams<Modules>): SendbirdChatWith<Modules>`), so `ReturnType<typeof SendbirdChat.init>` is `SendbirdChatWith<Module[]>`, while `SendbirdChat.init({ appId, modules: [] })` returns `SendbirdChatWith<never[]>`; assigning one to the other fails with TS2322. When the app uses no channel module, type the variable as `SendbirdChat` (the default export is also the instance type). (source: `@sendbird/chat` 4.22.14 `lib/__definition.d.ts` line 4240 `static init`, line 4825 `type SendbirdChatWith<Modules extends Module[]> = SendbirdChat & ModuleNamespaces<Modules>`)
- Rule: never import a channel type or a module wrapper type (`SendbirdGroupChat`, `GroupChannel`, `GroupChannelModule`, `SendbirdOpenChat`) from the root `@sendbird/chat`. The root does not export them, so `import { SendbirdGroupChat } from '@sendbird/chat'` fails with TS2724 ("has no exported member named 'SendbirdGroupChat'"). Import them from `@sendbird/chat/groupChannel` or `@sendbird/chat/openChannel`, and message types from `@sendbird/chat/message`.
- (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication — imports `SendbirdGroupChat` from `@sendbird/chat/groupChannel` and casts the `SendbirdChat.init` result to it) (source: `@sendbird/chat` 4.22.13 `package.json` `exports` (`.`, `./message`, `./groupChannel`, `./openChannel`, `./poll`, `./feedChannel`, `./aiAgent`, `./node`) and the export lists in `index.d.ts`, `groupChannel.d.ts`, `openChannel.d.ts`, `message.d.ts`; the four lists are identical in 4.22.11 and 4.22.14; `lib/__definition.d.ts`:6752 `SendbirdGroupChat = SendbirdChatWith<[GroupChannelModule]>` — verified 2026-10-19; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/modules/_sendbird_chat_groupChannel.html)

## Connect a user (auth)
```ts
const user = await sb.connect(USER_ID);            // or sb.connect(USER_ID, ACCESS_TOKEN)
```
Pass an access/session token as the second arg for authenticated apps — see `knowledge/curated/js/products/auth.md`. (source: sendbird.com/docs chat v4 javascript getting-started)

## Call APIs only after connect completes
Apart from initializing, the SDK must be connected before almost every call. Await `connect` first, check the connection state, and wait for the connection handler when it is not open yet.
```ts
import { ConnectionHandler, ConnectionState } from '@sendbird/chat';

await sb.connect(USER_ID);
if (sb.connectionState === ConnectionState.OPEN) {
  const total = await sb.groupChannel.getTotalUnreadMessageCount();
} else {
  // Local caching: connected to cached data only. Call server APIs once the connection opens.
  sb.addConnectionHandler('unread-after-connect', new ConnectionHandler({
    onReconnectSucceeded: async () => {
      sb.removeConnectionHandler('unread-after-connect');
      const total = await sb.groupChannel.getTotalUnreadMessageCount();
    },
  }));
}
```
- Apart from initializing, connect before calling almost every Chat SDK method; a call made without a connection returns `CONNECTION_REQUIRED` (800101). With local caching, the app can draw the channel list and chat view offline from cached data: the SDK hands back the user from a previous successful connection and tries to reconnect later. After 400300, 400301, 400302, or 400310, clear the cached user data and reconnect instead. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication — reviewed 2026-10-11)
- `onConnected` fires when the SDK connects successfully; `onReconnectSucceeded` fires after an automatic reconnection. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-connection-event-handlers/add-or-remove-a-connection-event-handler — reviewed 2026-10-11)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat` 4230 — `currentUser` 4288, `connectionState` 4292, `connect(userId, authToken?)` 4372, `addConnectionHandler` 4429, `removeConnectionHandler` 4434; `ConnectionState` 1340 (`OPEN` 1342); `ConnectionHandlerParams` 1320 — `onConnected` 1322, `onReconnectSucceeded` 1326; `GroupChannelModule.getTotalUnreadMessageCount(params?)` 6275; `ConnectionHandler` and `ConnectionState` are exported from `@sendbird/chat` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

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
import type { BaseChannel } from '@sendbird/chat';
import { GroupChannelFilter, GroupChannelListOrder, type GroupChannel } from '@sendbird/chat/groupChannel';

const collection = sb.groupChannel.createGroupChannelCollection({
  filter: new GroupChannelFilter(),   // e.g. filter.includeEmpty = true
  order: GroupChannelListOrder.LATEST_LAST_MESSAGE,
});

// The handlers receive BaseChannel[]; narrow them before they go into GroupChannel[] state.
const asGroup = (list: BaseChannel[]) => list.filter((c): c is GroupChannel => c.isGroupChannel());
collection.setGroupChannelCollectionHandler({
  onChannelsAdded: (context, channels) => { /* add asGroup(channels) to UI state */ },
  onChannelsUpdated: (context, channels) => { /* replace rows by url with asGroup(channels) */ },
  onChannelsDeleted: (context, channelUrls) => { /* remove rows */ },
});

const channels = await collection.loadMore();   // GroupChannel[]; first page, call again to paginate
// collection.dispose() when the screen unmounts
```
The handler arguments are typed `BaseChannel[]`, so passing them straight into `GroupChannel[]` state (for example `setChannels((prev) => [...channels, ...prev])` in React) fails to type-check. Narrow them with the `isGroupChannel()` type guard, as above; `loadMore()` and the `channels` getter already return `GroupChannel[]`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:196 `isGroupChannel(): this is GroupChannel` on `BaseChannel` :169, :5347 `get channels(): GroupChannel[]`, :5374 `onChannelsAdded?: (context, channels: BaseChannel[])`, :5376 `onChannelsUpdated?: (context, channels: BaseChannel[])`)
`createGroupChannelCollection(params?: GroupChannelCollectionParams)` is on `GroupChannelModule`; `setGroupChannelCollectionHandler(handler)` and `loadMore(): Promise<GroupChannel[]>` are on the returned `BaseChannelCollection`, along with `hasMore` and event fields `onChannelsAdded` / `onChannelsUpdated` / `onChannelsDeleted`. `dispose()` is declared on `GroupChannelCollection` itself. A one-shot alternative exists as `sb.groupChannel.createMyGroupChannelListQuery(params)` (returns a `GroupChannelListQuery`), and `createPublicGroupChannelListQuery(params)` lists channels the current user hasn't joined yet. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:6156 `createGroupChannelCollection`, :6162 `createMyGroupChannelListQuery`, :6175 `createPublicGroupChannelListQuery`, :5338-5357 `BaseChannelCollection` incl. `setGroupChannelCollectionHandler`/`loadMore`/`hasMore`, :5502-5506 `GroupChannelCollection.dispose`, :5374-5378 `onChannelsAdded/Updated/Deleted`, :5918 `GroupChannelListOrder`)

## Send a message
```ts
const params = { message: TEXT_MESSAGE };          // UserMessageCreateParams
channel.sendUserMessage(params)
  .onPending((m) => {})
  .onFailed((err, m) => { if (m) { /* keep the failed message to offer a retry */ } })
  .onSucceeded((m) => {});
```
`channel` from `sb.groupChannel.createChannel(params)` (group) or the open-channel API. (source: sendbird.com/docs chat v4 javascript getting-started)
The failed message passed to `onFailed` can be `null`, so check it before adding it to a `BaseMessage[]` list. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:1627 `FailedMessageHandler<T> = (err: Error, message: T | null) => void`, :2889 `MessageRequestHandler.onFailed`)

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
import { MessageFilter, MessageCollectionInitPolicy } from '@sendbird/chat/groupChannel';
import type { BaseMessage } from '@sendbird/chat/message';

// reqId is on user, file, and multiple-files messages; the type guards narrow to them.
function requestIdOf(m: BaseMessage): string {
  return m.isUserMessage() || m.isFileMessage() || m.isMultipleFilesMessage() ? m.reqId : '';
}

// A pending message and its sent copy share reqId; other messages match by messageId.
function sameMessage(a: BaseMessage, b: BaseMessage): boolean {
  const ra = requestIdOf(a);
  const rb = requestIdOf(b);
  if (ra && rb) return ra === rb;
  return a.messageId === b.messageId;
}

// A list key that stays the same while a pending message becomes the sent one.
function messageKey(m: BaseMessage): string {
  const reqId = requestIdOf(m);
  return reqId ? `req-${reqId}` : `id-${m.messageId}`;
}

// Every batch goes through here: replace matching rows, then oldest first.
function mergeMessages(current: BaseMessage[], incoming: BaseMessage[]): BaseMessage[] {
  const kept = current.filter((m) => !incoming.some((n) => sameMessage(m, n)));
  return [...kept, ...incoming].sort((a, b) => a.createdAt - b.createdAt);
}

let rows: BaseMessage[] = [];   // the list your view renders, oldest at the top

const collection = channel.createMessageCollection({
  filter: new MessageFilter(),
  startingPoint: Date.now(),
  prevResultLimit: 30,   // `limit` is deprecated since v4.10.5
  nextResultLimit: 30,
});

collection.initialize(MessageCollectionInitPolicy.CACHE_AND_REPLACE_BY_API)
  .onCacheResult((err, messages) => { if (messages) rows = mergeMessages([], messages); })   // cached page, shown immediately
  .onApiResult((err, messages) => { if (messages) rows = mergeMessages([], messages); });    // replaces it with the server's page

collection.setMessageCollectionHandler({
  onMessagesAdded: (context, channel, messages) => { rows = mergeMessages(rows, messages); },
  onMessagesUpdated: (context, channel, messages) => { rows = mergeMessages(rows, messages); },   // e.g. a pending message resolved
  onMessagesDeleted: (context, channel, messageIds, messages) => {
    rows = rows.filter((m) => !messages.some((d) => sameMessage(m, d)));
  },
});

// Pagination, driven by the collection's own cursors:
if (collection.hasPrevious) rows = mergeMessages(rows, await collection.loadPrevious());
if (collection.hasNext) rows = mergeMessages(rows, await collection.loadNext());
// collection.dispose() when the screen unmounts
```
Do not put the `onCacheResult` / `onApiResult` array into the view as it arrives. Neither the type declarations nor the message collection docs page state the order of that array (the docs page only says loading from `startingPoint: Date.now()` goes from the newest message back), so a view that renders it directly can show the newest message at the top, typically when a cached channel is reopened. Pass every batch (cache result, API result, added, updated, `loadPrevious()`, `loadNext()`) through one merge that sorts by `createdAt`, as above. The official React sample also reorders both arrays itself before rendering. In a React list, key each row with the key helper above: it follows the same match as the merge, so the key stays the same when the sent copy replaces the pending one. Read `reqId` only after `isUserMessage()`, `isFileMessage()`, or `isMultipleFilesMessage()`: it is declared on `SendableMessage`, which the package does not export, not on `BaseMessage`, so `'reqId' in m` leaves `m.reqId` typed `unknown` and a key built from it fails the type check. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:2579-2596 `MessageCollectionInitHandler` (no order stated), :853 `BaseMessage.messageId`, :2823 `MessagePrototype.createdAt`, :2842 `isUserMessage(): this is UserMessage`, :2847 `isFileMessage`, :2852 `isMultipleFilesMessage`, :4215-4218 `declare class SendableMessage` `reqId: string` ; source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/using-message-collection/message-collection ; source: https://github.com/sendbird/sendbird-chat-sample-react/blob/main/src/samples/BasicGroupChannelSample.js `messages.reverse()` in `onCacheResult` / `onApiResult`)
`channel.createMessageCollection(params?: MessageCollectionParams)`, `.initialize(policy)` returning `.onCacheResult(handler)` / `.onApiResult(handler)`, `.setMessageCollectionHandler(handler)`, `.hasPrevious` / `.hasNext`, `.loadPrevious()` / `.loadNext()` are all on `MessageCollection` (`GroupChannel.createMessageCollection` :1992). `onMessagesDeleted` takes a 4th `messages` arg alongside the (v4.3.1-deprecated) `messageIds`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:1992, :2559-2610 `MessageCollection`/`MessageCollectionInitHandler`, :963-983 `loadPrevious`/`loadNext`/`hasPrevious`/`hasNext`, :1026-1048 `onMessagesAdded`/`onMessagesUpdated`/`onMessagesDeleted`, :1057-1066 `BaseMessageCollectionParams` (`limit` deprecated since v4.10.5 in favor of `prevResultLimit`/`nextResultLimit`))

## Local caching and offline messages
Local caching keeps group channels and messages on the device, so the channel list and chat view built with the collections above also work offline. Turn it on or off once, in `SendbirdChat.init`:
```ts
import SendbirdChat, { CachedDataClearOrder, LocalCacheConfig } from '@sendbird/chat';
import { GroupChannelModule } from '@sendbird/chat/groupChannel';

const sb = SendbirdChat.init({
  appId: APP_ID,
  localCacheEnabled: true,                    // false (the default) turns local caching off
  localCacheConfig: new LocalCacheConfig({
    maxSize: 256,                             // MB; default 256, minimum 64
    clearOrder: CachedDataClearOrder.MESSAGE_COLLECTION_ACCESSED_AT,   // default
  }),
  modules: [new GroupChannelModule()],
});
```
```ts
// With a MessageCollection (see "List and receive messages"):
const olderPage = await collection.loadPrevious();   // the previous page
const sending = collection.pendingMessages;           // with local caching, resent when the connection returns
const failed = collection.failedMessages;             // not resent automatically
```
- Browsers keep the cache in IndexedDB; when IndexedDB is not available the SDK falls back to memory and logs a warning. React Native has no IndexedDB: pass an MMKV instance from `react-native-mmkv` as `useMMKVStorageStore` (do not clear or edit that MMKV data yourself). `useAsyncStorageStore` is deprecated. With several browser tabs on one app, set `supportMultipleTabs: true` (only with `localCacheEnabled`). (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication, https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation, https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/overview-local-caching — reviewed 2026-10-11)
- `LocalCacheConfig.maxSize` defaults to 256 MB (values under 64 MB become 64 MB). The SDK checks the cache size on the first `connect` after initialization and, past the limit, clears cached messages in `clearOrder`. `sb.clearCachedData()` erases everything, `sb.clearCachedMessages(channelUrls)` the given channels' messages, and `sb.getCacheDataSize()` reports the size (the docs spell it `getCachedDataSize()`; the shipped type is `getCacheDataSize`). (source: same overview page)
- Reconnecting after a long time offline: the SDK fills small gaps through changelog sync. When more than 300 messages are missing from the cache, it calls `onHugeGapDetected`; dispose the collection and create a new one instead of paging through the gap. Contact Sendbird support to change the 300 threshold. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/using-message-collection/message-collection — reviewed 2026-10-11)
- `loadPrevious()` resolves with the previous page; the docs call it only when `hasPrevious` is true. (source: same message collection page)
- Messages sent while offline, with local caching: a user message that could not go out because the WebSocket connection was lost is kept as **pending** and resent automatically when the connection comes back (auto resend). A file message waits the same way when the network is down. When the resend succeeds, `onMessagesUpdated` reports it and `message.sendingStatus` reads `SendingStatus.SUCCEEDED`. A send that fails for another reason, such as a network error or an ack timeout, is reported as **failed** and is not resent automatically. A pending message older than three days is marked failed when the connection returns. Resend and final-state handling: knowledge/curated/js/cross-cutting/pitfalls.md. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/overview-local-caching — reviewed 2026-10-11)
- `sb.disconnect()` clears the local cache; `sb.disconnectWebSocket()` keeps it (see knowledge/curated/js/products/auth.md).
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChatParams` 4805 — `localCacheEnabled` 4815, `localCacheConfig` 4816, `supportMultipleTabs` 4818, deprecated `useAsyncStorageStore` 4819-4820, `useMMKVStorageStore` 4821; `LocalCacheConfig` 2353, `LocalCacheConfigParams` 2368 — `maxSize` 2369, `clearOrder` 2370; `SendbirdChat` — `getCacheDataSize()` 4343, `clearCachedData()` 4347, `clearCachedMessages(channelUrls)` 4352; `BaseMessageCollection` 948 — `failedMessages` 960, `pendingMessages` 962, `loadPrevious()` 977; `onHugeGapDetected` 1054; `LocalCacheConfig` and `CachedDataClearOrder` are exported from `@sendbird/chat` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.LocalCacheConfig.html)

## Message threads
A reply carries its parent's message ID. Threads are one level deep, so a reply to a reply must point at the thread's root message.
```ts
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';

// Reply in a thread (`message` is a UserMessage).
const parentMessageId = message.parentMessageId || message.messageId;
channel.sendUserMessage({ message: 'Thanks!', parentMessageId })
  .onSucceeded((reply) => {});

// List the replies of a parent message, starting at the parent's timestamp.
const { parentMessage, threadedMessages } = await message.getThreadedMessagesByTimestamp(message.createdAt, {
  prevResultSize: 0,
  nextResultSize: 30,
  includeParentMessageInfo: true,
});

// Keep the parent's reply count current.
sb.groupChannel.addGroupChannelHandler('threads', new GroupChannelHandler({
  onThreadInfoUpdated: (channel, threadInfoUpdateEvent) => {
    // Find the parent whose messageId === threadInfoUpdateEvent.targetMessageId,
    // then call parent.applyThreadInfoUpdateEvent(threadInfoUpdateEvent).
  },
}));
```
- Only user and file messages can be threaded: a reply to a reply is rejected, and admin messages can't be replies or have replies. A message that is not a reply has `parentMessageId` 0. When a reply is created or deleted, `onThreadInfoUpdated` fires with the latest thread information. `isReplyToChannel` on the create params also sends the reply to the channel (default `false`, per its doc comment at `lib/__definition.d.ts` line 1087). (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/using-message-threading/create-a-message-thread, https://sendbird.com/docs/chat/sdk/v4/javascript/message/using-message-threading/list-replies-in-a-message-thread — reviewed 2026-10-11)
- `getThreadedMessagesByTimestamp` is declared on `UserMessage`, `FileMessage`, and `AdminMessage` (and the multiple-files message), not on `BaseMessage`, so narrow the type first (for example with `message.isUserMessage()`). `message.threadInfo` has `replyCount`, `mostRepliedUsers`, and `lastRepliedAt`. `MessageFilter.replyType` takes `ReplyType.NONE`, `ALL`, or `ONLY_REPLY_TO_CHANNEL`.
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `BaseMessageCreateParams` 1071 — `parentMessageId` 1085, `isReplyToChannel` 1087; `BaseMessage` 851 — `messageId` 853, `parentMessageId` 855, `threadInfo` 863, `applyThreadInfoUpdateEvent` 891; `MessagePrototype.createdAt` 2823; `getThreadedMessagesByTimestamp(ts, params)` on `AdminMessage` 16, `FileMessage` 1778, `MultipleFilesMessage` 3123, `UserMessage` 5282; `ThreadedMessageListParams` 4984 — `prevResultSize` 4986, `nextResultSize` 4988, `includeParentMessageInfo` 5004; `ThreadInfo` 5024; `ThreadInfoUpdateEvent.targetMessageId` 5051; `BaseChannelHandlerParams.onThreadInfoUpdated` 5436; `MessageFilter.replyType` 2625; `ReplyType` 4077 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_message.UserMessage.html)

## Admin messages
A client SDK does not send admin messages: the docs list Sendbird Dashboard and the Chat Platform API as the ways to send one, and the SDK has no send method for them. They arrive like other messages, as `AdminMessage`, through the message collection and the channel handler.
```ts
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';

sb.groupChannel.addGroupChannelHandler('admin-notices', new GroupChannelHandler({
  onMessageReceived: (channel, message) => {
    if (message.isAdminMessage()) {
      // An admin message: a system message sent without a sender.
    }
  },
}));
```
- An admin message is a system message sent without a sender, and in a group channel the sender does not need to be a member. Delivery receipts, message search, and message threading do not apply to admin messages. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/overview-message — the message type table, https://sendbird.com/docs/chat/sdk/v4/javascript/message/sending-a-message/send-an-admin-message — reviewed 2026-10-11)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `AdminMessage extends BaseMessage` 6; `MessagePrototype.isAdminMessage()` 2857; `BaseChannelHandlerParams.onMessageReceived` 5426 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_message.AdminMessage.html)

## Custom type, data, and channel metadata
```ts
// A message's customType and data travel with the message.
channel.sendUserMessage({ message: TEXT_MESSAGE, customType: 'order-update', data: JSON.stringify({ orderId: '1234' }) })
  .onSucceeded((sent) => { /* receivers read sent.customType and sent.data */ });

// Channel metadata: string key-value pairs stored on the channel.
await channel.createMetaData({ theme: 'dark' });
await channel.updateMetaData({ theme: 'light', layout: 'compact' }, true);   // true: add keys that don't exist yet
const metaData = await channel.getMetaData(['theme']);
const cachedMetaData = channel.cachedMetaData;        // no server call
```
- `customType` subclassifies messages and is useful for searching or filtering; `data` carries any extra string. Channel metadata stores extra information on the channel, such as a background color or a description. `updateMetaData(data, upsert?)` updates existing keys; the docs pass `true` as the second argument (`upsertIfKeyNotExist`) to add new keys too. The SDK caches metadata after any create, read, update, or delete and when a channel list is fetched; `cachedMetaData` reads that cache. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/categorizing-messages/categorize-messages-by-custom-type, https://sendbird.com/docs/chat/sdk/v4/javascript/channel/managing-channel-metadata/manage-channel-metadata — reviewed 2026-10-11)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `BaseMessageCreateParams` 1071 — `data` 1073, `customType` 1075; `MessagePrototype` — `data` 2807, `customType` 2809; `BaseChannel` 169 — `cachedMetaData` 208, `getMetaData(keys)` 273, `createMetaData(data)` 284, `updateMetaData(data, upsert?)` 291, `deleteMetaData(key)` 296; `MetaData` 3096 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.BaseChannel.html)

## Update the user profile
```ts
const me = await sb.updateCurrentUserInfo({
  nickname,
  profileUrl,          // or profileImage: a File to upload the image
});
```
- Updates the current user's nickname and profile image. An uploaded profile image can be a JPG, JPEG, or PNG file of up to 5 MB. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/user/retrieving-and-updating-user-information/update-user-profile — reviewed 2026-10-11)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat.updateCurrentUserInfo(params?)` 4486; `UserUpdateParams` 5329 — `profileImage` 5331, `profileUrl` 5333, `nickname` 5335 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

## Reactions
```ts
await channel.addReaction(message, ':+1:');     // key = an emoji key configured on the app
await channel.deleteReaction(message, ':+1:');
```
Both are on `BaseChannel`, so they work for group and open channels identically; each returns a `ReactionEvent`. (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:169 `BaseChannel`, :552 `addReaction`, :559 `deleteReaction`)

To show reactions, read `message.reactions` (a `Reaction[]`): each `Reaction` has `key`, `count`, and `sampledUserIds` (a sample of who reacted). Do not use `Reaction.userIds`: it is deprecated since 4.15.0 in favor of `sampledUserIds`. (source: `@sendbird/chat@4.22.0` lib/__definition.d.ts:844 `reactions` on `BaseMessage`, :3981 `Reaction`, :3986 `userIds` "@deprecated Since v4.15.0 Use sampledUserIds instead", :3989 `sampledUserIds`, :3993 `count` — verified 2026-10-24)

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
- The per-custom-type counts in this event (`customTypeUnreadCount` on the `UnreadMessageCount` the handler receives; the docs page calls the attribute `countByCustomTypes`, a name the SDK does not have) are turned off by default; the app owner must contact Sendbird to enable them. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.UserEventHandler.html ; `@sendbird/chat@4.22.13` lib/__definition.d.ts:5115-5121 `customTypeUnreadCount` on `UnreadMessageCount`, :5249 `onTotalUnreadMessageCountChanged`) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler — reviewed 2026-10-06)
- The JavaScript page names only the per-custom-type counts as off by default. The Android page differs and turns off its whole event by default, so the Android curated doc says so. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler ; https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler — reviewed 2026-10-16)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannel` 1872 — `unreadMessageCount` 1903; `GroupChannelModule` 6149 — `getTotalUnreadMessageCount(params?)` 6275; `SendbirdChat` 4230 — `addUserEventHandler(key, handler)` 4414; `UserEventHandler` 5239, `UserEventHandlerParams` 5243 — `onTotalUnreadMessageCountChanged` 5249 — verified 2026-10-05)
- The total counts unread messages in all group channels the user joined; it can be filtered by channel custom type or super-channel type. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/retrieving-unread-counts-in-a-group-channel/unread-messages-in-all-channels — reviewed 2026-10-05)

## Hide or archive a channel
```ts
import { HiddenChannelFilter, HiddenState } from '@sendbird/chat/groupChannel';

await channel.hide({ hidePreviousMessages: false, allowAutoUnhide: true });    // returns to the list on a new message
await channel.hide({ hidePreviousMessages: false, allowAutoUnhide: false });   // archived until unhide()
await channel.unhide();
const isArchived = channel.hiddenState === HiddenState.HIDDEN_PREVENT_AUTO_UNHIDE;

const archivedQuery = sb.groupChannel.createMyGroupChannelListQuery({
  hiddenChannelFilter: HiddenChannelFilter.HIDDEN_PREVENT_AUTO_UNHIDE,
});
```
- `allowAutoUnhide: true` (the default) hides the channel until a new message arrives; `false` archives it until `unhide()` is called. `hidePreviousMessages: true` stops showing the messages sent before hiding (default `false`). (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/managing-channels/hide-or-archive-a-group-channel-from-a-list-of-channels — reviewed 2026-10-11)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannel` 1872 — `hiddenState` 1915, `hide(params)` 2115, `unhide()` 2120; `GroupChannelHideParams` 2273; `HiddenState` 2331; `HiddenChannelFilter` 6361; `hiddenChannelFilter` on the group channel list params 5981; both enums are exported from `@sendbird/chat/groupChannel` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html)

## Moderation (ban, mute, block, freeze)
```ts
import { Role } from '@sendbird/chat';
import { MutedState } from '@sendbird/chat/groupChannel';

// Operators only: check `channel.myRole === Role.OPERATOR` first. `channel` is a GroupChannel.
await channel.banUserWithUserId('USER_ID', 600, 'Spam');   // removed for 600 s; -1 bans indefinitely
await channel.unbanUserWithUserId('USER_ID');
await channel.muteUserWithUserId('USER_ID', 600);          // stays in the channel, cannot send
await channel.unmuteUserWithUserId('USER_ID');
await channel.freeze();                                     // while frozen, only operators can send
await channel.unfreeze();
const muted = channel.myMutedState === MutedState.MUTED;

// Any user: block another user
await sb.blockUser('USER_ID');      // accepts a User or a userId
await sb.unblockUser('USER_ID');
```
- Ban, mute, and freeze are operator actions. A banned user is removed from the channel and can rejoin after the set time; a muted user stays in the channel and can read but not send. While a group channel is frozen only operators can send; open channels are frozen only through the Chat API or the dashboard, not the SDK. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/user/moderating-a-user/ban-and-unban-a-user, https://sendbird.com/docs/chat/sdk/v4/javascript/user/moderating-a-user/mute-and-unmute-a-user, https://sendbird.com/docs/chat/sdk/v4/javascript/channel/moderating-a-channel/freeze-and-unfreeze-a-channel — reviewed 2026-10-06)
- Blocking: in a 1-to-1 group channel the blocker no longer receives the blocked user's messages or notifications; in a 1-to-N channel messages may still show depending on the chat UI, and by default notifications from the blocked user are not delivered (Sendbird can turn them on for individual channels on request). (source: https://sendbird.com/docs/chat/sdk/v4/javascript/user/moderating-a-user/block-and-unblock-other-members — reviewed 2026-10-06)
- Events: `onUserBanned`, `onUserMuted`, `onChannelFrozen`, `onChannelUnfrozen` on the `GroupChannelHandler` (see "Handle incoming events without a collection"). Lists: `sb.createBlockedUserListQuery()`. `banUser(user, ...)` and `muteUser(user, ...)` take a `User` instead of an id.
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `BaseChannel` — `isFrozen` 187, `muteUser` 353, `muteUserWithUserId` 360, `unmuteUserWithUserId` 371, `banUser` 381 (JSDoc: pass -1 to ban indefinitely), `banUserWithUserId` 388, `unbanUserWithUserId` 399; `GroupChannel` — `myRole` 1925, `myMutedState` 1927, `freeze` 2061, `unfreeze` 2062; `MutedState` 3189; `Role` 4127; `SendbirdChat` — `createBlockedUserListQuery` 4450, `blockUser` 4661, `unblockUser` 4672; `BaseChannelHandlerParams` — `onUserMuted` 5395, `onUserBanned` 5399, `onChannelFrozen` 5407, `onChannelUnfrozen` 5409; no `@deprecated` on any of them; `Role` is exported from `@sendbird/chat`, `MutedState` from `@sendbird/chat/groupChannel` — verified 2026-10-06)

## Invite members and manage operators
```ts
// `channel` is a GroupChannel
await channel.inviteWithUserIds(['USER_ID']);
await channel.addOperators(['USER_ID']);      // operators can mute, ban, and freeze
await channel.removeOperators(['USER_ID']);   // stays a member
```
- A private group channel can be joined only by invitation from a member. Whether a new member sees messages sent before the invite is an app setting, on by default. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/inviting-users-to-a-group-channel/invite-users-as-members, https://sendbird.com/docs/chat/sdk/v4/javascript/channel/managing-operators/register-and-remove-operators — reviewed 2026-10-07)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannel.inviteWithUserIds` 2080; `BaseChannel.addOperators` 257, `removeOperators` 262 — verified 2026-10-07)

## Pinned messages
```ts
await channel.pinMessage(message.messageId);
await channel.unpinMessage(message.messageId);
const pinnedIds: number[] = channel.pinnedMessageIds;

const pinnedQuery = channel.createPinnedMessageListQuery({ limit: 20 });
const pinned = await pinnedQuery.next();                 // PinnedMessage[]
const messages = pinned.map((p) => p.message);           // BaseMessage | null
```
- Up to 10 messages can be pinned per channel by default. Group channels support pinning except ephemeral channels; Supergroup channels do not. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/managing-pinned-messages-in-group-channels/pin-a-message — reviewed 2026-10-07)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `BaseChannel.pinnedMessageIds` 171, `createPinnedMessageListQuery` 252, `pinMessage` 691, `unpinMessage` 696; `PinnedMessage.message` 3504; `PinnedMessageListQuery.next` 3538 — verified 2026-10-07)

## Search messages
```ts
const searchQuery = sb.createMessageSearchQuery({
  keyword: 'refund',
  channelUrl: channel.url,   // omit to search every joined group channel
  limit: 20,
});
const found = await searchQuery.next();   // call again while searchQuery.hasNext
```
- Searches group channel messages. Punctuation and special characters are ignored when indexing; `AND` and `OR` (uppercase) combine terms; a term shorter than two characters matches exactly only. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/searching-messages-in-a-group-channel/search-messages-by-a-keyword — reviewed 2026-10-07)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat.createMessageSearchQuery` 4462; `MessageSearchQueryParams.keyword` 3015, `channelUrl` 3027; `MessageSearchQuery.next` 3008 — verified 2026-10-07)

## Filter the channel list by name
```ts
const listQuery = sb.groupChannel.createMyGroupChannelListQuery({ channelNameContainsFilter: 'support' });
const channels = await listQuery.next();
```
- (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/searching-channels/search-group-channels-by-name-url-or-other-filters — reviewed 2026-10-07; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannelModule.createMyGroupChannelListQuery` 6162, `GroupChannelFilterParams.channelNameContainsFilter` 5812, `GroupChannelListQuery.next` 6144 — verified 2026-10-07)

## Read receipts for a message
```ts
const unreadCount = channel.getUnreadMemberCount(message);   // 0 = every member has read it
const readers = channel.getReadMembers(message);             // pass true to include the current user
```
- Re-render when `onUserMarkedRead(channel, userIds)` fires on the `GroupChannelHandler` (see "Handle incoming events without a collection"); the server calls it after another member's `markAsRead()`. Do not use `onUnreadMemberStatusUpdated`: it is deprecated since 4.18.2 and its JSDoc points to `onUserMarkedRead`, although the public "members who haven't read a message" page still shows it. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/managing-read-status-in-a-group-channel/mark-messages-as-read — reviewed 2026-10-16; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannelHandlerParams.onUnreadMemberStatusUpdated` 5890 with `@deprecated since v4.18.2 Please use onUserMarkedRead instead.` at 5886, `onUserMarkedRead` 5892 — verified 2026-10-16)
- (source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/managing-read-status-in-a-group-channel/get-read-status — reviewed 2026-10-07; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `GroupChannel.getUnreadMemberCount` 2012, `getReadMembers` 2027, `getReadStatus` 2040 — verified 2026-10-07)

## Connection state and reconnection
```ts
import { ConnectionHandler } from '@sendbird/chat';

sb.addConnectionHandler('connection-banner', new ConnectionHandler({
  onReconnectStarted: () => { /* show "Reconnecting..." */ },
  onReconnectSucceeded: () => { /* hide the banner and refresh */ },
  onReconnectFailed: () => { /* offer a manual retry */ },
}));
// sb.removeConnectionHandler('connection-banner') on cleanup
```
- The SDK reconnects by itself after a network drop; these callbacks only report it. `onConnected` and `onDisconnected` are also available. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-connection-event-handlers/add-or-remove-a-connection-event-handler — reviewed 2026-10-07)
- (source: `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat.addConnectionHandler` 4429, `removeConnectionHandler` 4434; `ConnectionHandler` 1316, `ConnectionHandlerParams` 1320 — `onReconnectStarted` 1324, `onReconnectSucceeded` 1326, `onReconnectFailed` 1328 — verified 2026-10-07, line numbers corrected 2026-10-11)

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

`onMessageReceived` is not called on the device that sent the message: the docs list its notified devices as every device with the channel open in the foreground except the sender's. Your own sent message comes back through the `sendUserMessage` / `sendFileMessage` request handlers (`onSucceeded`) instead. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-channel-event-handlers/add-or-remove-a-channel-event-handler — "List of group channel events")

## React vs React Native
- The core SDK is identical; only the surrounding app differs. Templates: `templates/js/react/chat/`, `templates/js/react-native/chat/`.
- For full prebuilt UI use Sendbird UIKit (`@sendbird/uikit-react` / `@sendbird/uikit-react-native`) — see `knowledge/curated/js/products/uikit.md`.

## Pitfalls
- Import `SendbirdGroupChat`, `GroupChannel`, and `GroupChannelModule` from `@sendbird/chat/groupChannel`, never from the root `@sendbird/chat` (TS2724). Check the "Import paths" table above before writing any Chat SDK import.
- Initialize once and reuse the returned `sb` instance; do not re-init per render/component.
- App ID read from env (e.g. `process.env.NEXT_PUBLIC_SENDBIRD_APP_ID`); access/session tokens are secrets — never hard-code or log.
- Every collection (`GroupChannelCollection`, `MessageCollection`) and every `addGroupChannelHandler` call must be paired with `dispose()` / `removeGroupChannelHandler()` when the owning screen unmounts, or the SDK keeps delivering events to a dead view.
- In strict TypeScript, `onChannelsAdded`/`onChannelsUpdated` type their `channels` param as `BaseChannel[]`, not `GroupChannel[]`, even inside a `GroupChannelCollection` — cast (it is always safe here) rather than fighting the type.
- A message collection's `loadPrevious()` and `loadNext()` do not reject when a load in the same direction is still running: in 4.22.13 the second call logs "Messages are already fetching." and resolves with an empty array. So an empty result does not by itself mean there are no more messages; `hasPrevious` and `hasNext` say whether more data is left in each direction. (source: https://unpkg.com/@sendbird/chat@4.22.13/lib/__bundle-a81b3a5d.js — `loadPrevious` and `loadNext` check `_isLoadingPrevious` / `_isLoadingNext`) (source: `@sendbird/chat@4.22.13` lib/__definition.d.ts:964-966 `hasPrevious`, `hasNext`; :977 `loadPrevious`, :982 `loadNext`)

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/send-first-message
- Auth/session: knowledge/curated/js/products/auth.md
- Errors: knowledge/curated/js/cross-cutting/errors.md
- Push (token methods, logout order): knowledge/curated/js/cross-cutting/push.md
