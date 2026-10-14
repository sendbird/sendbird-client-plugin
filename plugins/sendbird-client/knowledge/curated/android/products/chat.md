<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- status: populated -->
# android chat

> Verified against sendbird.com/docs (Chat SDK v4 Android getting-started, verified 2026-06-09) and the public mirror `sendbird/sendbird-chat-sdk-android`. The templates compiled against 4.36.4 in GitHub Actions run 34187419379 on 2026-09-08; 4.36.5 is an internal-only patch (auto-resend handling; no public API change per CHANGELOG) re-verified against the changelog on 2026-09-28. Channel list, message list, reactions, typing, read status, and handlers below verified against the real `sendbird-chat-4.36.5.aar` (downloaded from `https://repo.sendbird.com/public/maven`, decompiled with `javap -public`, verified 2026-09-29). The connect-ordering, local caching, thread, admin message, metadata, profile, and hide/archive sections were checked on 2026-10-11 against `javap -public` on the public `sendbird-chat-4.36.5.aar` and the linked Chat v4 Android docs pages. Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message

## Overview
Sendbird Chat is the foundation product (auth/session live here). Initialize once in the `Application` class, connect a user, then operate on channels to send/receive messages.

## Install (Gradle)
- Repo in `settings.gradle`: `maven { setUrl("https://repo.sendbird.com/public/maven") }`.
- Dependency: `implementation("com.sendbird.sdk:sendbird-chat:4.36.5")` (or `4.+`).

## Initialize (Application class)
```kotlin
SendbirdChat.init(
    InitParams(APP_ID, applicationContext, useCaching = true),
    object : InitResultHandler {
        override fun onMigrationStarted() { }
        override fun onInitFailed(e: SendbirdException) { }
        override fun onInitSucceed() { }
    }
)
```
(source: sendbird.com/docs chat v4 android getting-started)

Call `SendbirdChat.init()` from `Application.onCreate()`. If you call it from an Activity's or Fragment's `onCreate()` instead, set `isForeground = true` on `InitParams` (it defaults to `false`) so the SDK knows it is being initialized while the app is in the foreground. The docs warn that this placement needs extra care: when a push arrives while the app is in the background or killed, only the `Application` runs, so code that marks the push as delivered would find the SDK uninitialized (see knowledge/curated/android/cross-cutting/push.md — Mark a push as delivered).
```kotlin
SendbirdChat.init(
    InitParams(APP_ID, applicationContext, useCaching = true).apply {
        isForeground = true // init is called from an Activity or Fragment, not from Application.onCreate()
    },
    initResultHandler
)
```
(source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.params/-init-params/index.html)

## Connect a user (auth)
```kotlin
SendbirdChat.connect(userId) { user, e ->
    if (user != null) { /* connected */ }
}
```
Callback receives `(User?, SendbirdException?)`. Authenticated apps pass a session/access token — see `knowledge/curated/android/products/auth.md`. (source: sendbird.com/docs chat v4 android getting-started)

## Call APIs only after connect completes
Apart from initializing, the SDK must be connected before almost every call. Start calls that need the server from the `connect` callback, or check the connection state first and wait for the connection handler.
```kotlin
// App launch or push open: init, connect, then call APIs that need the server.
SendbirdChat.connect(USER_ID) { user, e ->
    if (user == null) return@connect          // not connected
    if (e != null) return@connect             // local caching: offline with cached data, wait for onReconnectSucceeded()
    SendbirdChat.getTotalUnreadMessageCount(handler = UnreadMessageCountHandler { groupChannelCount, _, err -> /* badge */ })
}

// Code that can run before connect finishes (a push handler, another screen):
if (SendbirdChat.connectionState == ConnectionState.OPEN) {
    SendbirdChat.getTotalUnreadMessageCount(handler = UnreadMessageCountHandler { groupChannelCount, _, err -> /* badge */ })
}
// Otherwise wait for ConnectionHandler.onConnected() or onReconnectSucceeded()
// (see "Connection state and reconnection").
```
- Get the `InitResultHandler` callback before connecting. Apart from initializing, connect before calling almost every Chat SDK method; a call made without a connection returns `ERR_CONNECTION_REQUIRED` (800101). (source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication — reviewed 2026-10-11)
- With local caching, `connect` can return the user together with an error: the app is offline and can draw the channel list and chat view from cached data, and the SDK connects later and calls `ConnectionHandler.onReconnectSucceeded()`. Server calls made in that state do not have a connection yet. The exception is 400300, 400301, 400302, or 400310: the SDK clears the cached user data. (source: same authentication page)
- `onConnected()` fires when the SDK first connects to the server; `onReconnectSucceeded()` fires after an automatic reconnection. (source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-connection-event-handlers/add-or-remove-a-connection-event-handler — reviewed 2026-10-11)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `SendbirdChat.connect(String, ConnectHandler)`, `getConnectionState()`, `getTotalUnreadMessageCount(GroupChannelTotalUnreadMessageCountParams, UnreadMessageCountHandler)`, `addConnectionHandler(String, ConnectionHandler)`; `com.sendbird.android.ConnectionState` — `CONNECTING`, `OPEN`, `CLOSED` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html)

## Create and list group channels
```kotlin
val params = GroupChannelCreateParams().apply {
    userIds = listOf(otherUserId)
    isDistinct = true   // reuse the existing 1:1 channel instead of creating a duplicate
}
GroupChannel.createChannel(params) { channel, e ->
    if (channel != null) { /* created */ }
}
```
`GroupChannel.createChannel(GroupChannelCreateParams, GroupChannelCallbackHandler)` is a static call on `GroupChannel`. (source: `sendbird-chat-sdk-android` 4.36.5 AAR (`sendbird-chat-4.36.5.aar`), `javap` on `com.sendbird.android.channel.GroupChannel`)

For a live-updating channel list, use a `GroupChannelCollection`:
```kotlin
val query = GroupChannel.createMyGroupChannelListQuery(GroupChannelListQueryParams())
val collectionHandler = object : GroupChannelCollectionHandler {
    override fun onChannelsAdded(context: GroupChannelContext, channels: List<GroupChannel>) { }
    override fun onChannelsUpdated(context: GroupChannelContext, channels: List<GroupChannel>) { }
    override fun onChannelsDeleted(context: GroupChannelContext, deletedChannelUrls: List<String>) { }
}
val collectionParams = GroupChannelCollectionCreateParams(query, collectionHandler)
val collection = SendbirdChat.createGroupChannelCollection(collectionParams)

collection.loadMore { channels, e ->
    // first page; call loadMore again while collection.hasMore
}
// collection.dispose() when the screen is destroyed
```
`GroupChannel.createMyGroupChannelListQuery(params)` builds the query; `GroupChannelCollectionCreateParams(query, handler)` bundles the query and handler; `SendbirdChat.createGroupChannelCollection(params)` is the actual factory (the `GroupChannelCollection` constructor itself takes internal SDK types and is not meant to be called directly). `.loadMore(GroupChannelsCallbackHandler)`, `.hasMore`, `.channelList`, and `.dispose()` are on `BaseGroupChannelCollection`. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` (`createGroupChannelCollection`), `com.sendbird.android.params.GroupChannelCollectionCreateParams`, `com.sendbird.android.collection.BaseGroupChannelCollection`, `com.sendbird.android.handler.GroupChannelCollectionHandler`)

## Send a message
```kotlin
channel.sendUserMessage(UserMessageCreateParams(MESSAGE)) { message, e ->
    if (e != null) { /* handle error */ }
}
```
`channel` is a `GroupChannel` (or `OpenChannel`); callback receives `(UserMessage?, SendbirdException?)`. (source: sendbird.com/docs chat v4 android getting-started)

### Send a file message
```kotlin
channel.sendFileMessage(FileMessageCreateParams(file)) { message, e -> }
```
`FileMessageCreateParams` also has constructors taking a file URL `String` or a `FileMessage` (for resend). (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.params.FileMessageCreateParams`, `BaseChannel.sendFileMessage`)

## Update and delete a message
```kotlin
channel.updateUserMessage(message.messageId, UserMessageUpdateParams("Edited text")) { updated, e ->
    if (e != null) { /* handle error */ return@updateUserMessage }
    // replace the old message in your list with `updated`
}

channel.deleteMessage(message) { e ->
    if (e != null) { /* handle error */ }
}
```
- File messages: `updateFileMessage(messageId, FileMessageUpdateParams, FileMessageHandler)`. Deleting by id: `deleteMessage(messageId, CompletionHandler)`.
- Other members are told through the channel handler: `onMessageUpdated(channel, message)` and `onMessageDeleted(channel, messageId)`.
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `com.sendbird.android.channel.BaseChannel` `updateUserMessage(long, UserMessageUpdateParams, UserMessageHandler)`, `updateFileMessage(long, FileMessageUpdateParams, FileMessageHandler)`, `deleteMessage(BaseMessage, CompletionHandler)`, `deleteMessage(long, CompletionHandler)`; `UserMessageUpdateParams(String)`; `BaseMessage.getMessageId()`; `BaseChannelHandler.onMessageUpdated(BaseChannel, BaseMessage)`, `onMessageDeleted(BaseChannel, long)` — verified 2026-10-05)
- A user can update or delete messages they sent; channel operators can update or delete any message in the channel. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/managing-a-message/update-a-message, https://sendbird.com/docs/chat/sdk/v4/android/message/managing-a-message/delete-a-message — reviewed 2026-10-05)

## List and receive messages
For a message list screen, use a `MessageCollection`:
```kotlin
val messageHandler = object : MessageCollectionHandler {
    override fun onMessagesAdded(context: MessageContext, channel: GroupChannel, messages: List<BaseMessage>) { }
    override fun onMessagesUpdated(context: MessageContext, channel: GroupChannel, messages: List<BaseMessage>) { }
    override fun onMessagesDeleted(context: MessageContext, channel: GroupChannel, messages: List<BaseMessage>) { }
    override fun onChannelUpdated(context: GroupChannelContext, channel: GroupChannel) { }
    override fun onChannelDeleted(context: GroupChannelContext, channelUrl: String) { }
    override fun onHugeGapDetected() { }
}
val collectionParams = MessageCollectionCreateParams(channel, MessageListParams(), System.currentTimeMillis(), messageHandler)
val collection = SendbirdChat.createMessageCollection(collectionParams)

collection.initialize(MessageCollectionInitPolicy.CACHE_AND_REPLACE_BY_API, object : MessageCollectionInitHandler {
    override fun onCacheResult(cachedList: List<BaseMessage>?, e: SendbirdException?) { /* render cached messages immediately */ }
    override fun onApiResult(apiResultList: List<BaseMessage>?, e: SendbirdException?) { /* replace with the server's authoritative page */ }
})

if (collection.hasPrevious) {
    collection.loadPrevious { messages, e -> }
}
// collection.dispose() when the screen is destroyed
```
`MessageCollectionCreateParams(channel, params, startingPoint, handler)` bundles the setup; `SendbirdChat.createMessageCollection(params)` is the factory. `.initialize(policy, handler)`, `.hasPrevious` / `.hasNext`, `.loadPrevious(handler)` / `.loadNext(handler)`, and `.dispose()` are on `BaseMessageCollection`. Unlike the JS/iOS SDKs, `MessageCollectionHandler`'s add/update/delete callbacks always pass the full `BaseMessage` list — there is no separate deprecated message-id array. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` (`createMessageCollection`), `com.sendbird.android.params.MessageCollectionCreateParams`, `com.sendbird.android.collection.BaseMessageCollection`, `com.sendbird.android.handler.BaseMessageCollectionHandler`, `com.sendbird.android.handler.MessageCollectionInitHandler`)

## Local caching and offline messages
Local caching keeps group channels and messages on the device, so the channel list and chat view built with the collections above also work offline. Turn it on or off once, in `InitParams`:
```kotlin
import com.sendbird.android.caching.CachedDataClearOrder
import com.sendbird.android.caching.LocalCacheConfig

val initParams = InitParams(APP_ID, applicationContext, useCaching = true).apply {   // useCaching = false turns caching off
    localCacheConfig = LocalCacheConfig().apply {
        maxSize = 256L                                                     // MB; default 256, minimum 64
        clearOrder = CachedDataClearOrder.MESSAGE_COLLECTION_ACCESSED_AT   // default
    }
}
SendbirdChat.init(initParams, initResultHandler)
```
```kotlin
fun showMessages(collection: MessageCollection) {
    val shown = collection.succeededMessages   // everything initialize(), loadPrevious(), loadNext(), and events added
    val sending = collection.pendingMessages   // still being sent; with local caching, resent when the connection returns
    val failed = collection.failedMessages     // not resent automatically
    collection.loadPrevious { olderPage, e ->
        // olderPage is also in collection.succeededMessages now
    }
}
```
- Local caching is off unless `useCaching` is `true`. `LocalCacheConfig.maxSize` defaults to 256 MB (values under 64 MB become 64 MB). The SDK checks the cache size on the first `connect` after initialization and, past the limit, clears cached messages in `clearOrder`. `SendbirdChat.clearCachedData(context, handler)` erases everything, `clearCachedMessages(channelUrl, handler)` one channel's messages, and `getCachedDataSize(context)` reports the size. (source: https://sendbird.com/docs/chat/sdk/v4/android/local-caching/overview-local-caching, https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication — reviewed 2026-10-11)
- The collection keeps the messages loaded by `initialize()`, `loadPrevious()`, `loadNext()`, and message events in `succeededMessages`, the most up-to-date list, so use it as the RecyclerView data source. `pendingMessages` are being sent; when sending ends they move to `succeededMessages` or `failedMessages`. (source: https://sendbird.com/docs/chat/sdk/v4/android/local-caching/using-message-collection/message-collection — reviewed 2026-10-11)
- Reconnecting after a long time offline: the SDK fills small gaps through changelog sync. When more than 300 messages are missing from the cache, it calls `onHugeGapDetected()`; dispose the collection and create a new one instead of paging through the gap. Contact Sendbird support to change the 300 threshold. (source: same message collection page)
- Messages sent while offline, with local caching: a user message that could not go out because the WebSocket connection was lost is kept as **pending** and resent automatically when the connection comes back (auto resend). A file message waits the same way when the network is down. When the resend succeeds, `onMessagesUpdated()` reports it with `context.messagesSendingStatus == SendingStatus.SUCCEEDED`. A send that fails for another reason, such as `SendbirdError.ERR_NETWORK` or `SendbirdError.ERR_ACK_TIMEOUT`, is reported as **failed** and is not resent automatically. A pending message older than three days is marked failed when the connection returns. Pending to sent/failed handling and resend: knowledge/curated/android/cross-cutting/pitfalls.md. (source: https://sendbird.com/docs/chat/sdk/v4/android/local-caching/overview-local-caching — reviewed 2026-10-11)
- `SendbirdChat.disconnect` is a logout and clears cached data; `disconnectWebSocket` keeps it (see knowledge/curated/android/products/auth.md).
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `InitParams(String, Context, boolean, ...)`, `InitParams.setLocalCacheConfig(LocalCacheConfig)`; `com.sendbird.android.caching.LocalCacheConfig` — `setMaxSize(long)`, `setClearOrder(CachedDataClearOrder)`; `CachedDataClearOrder`; `BaseMessageCollection` — `getSucceededMessages()`, `getPendingMessages()`, `getFailedMessages()`, `loadPrevious(BaseMessagesHandler)`; `BaseMessageCollectionHandler.onHugeGapDetected()`; `MessageContext.getMessagesSendingStatus()`; `SendbirdChat.clearCachedData(Context, CompletionHandler)`, `clearCachedMessages(String, CompletionHandler)`, `getCachedDataSize(Context)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.collection/-base-message-collection/index.html)

## Message threads
A reply carries its parent's message ID. Threads are one level deep, so a reply to a reply must point at the thread's root message.
```kotlin
// Reply in a thread.
val parentId = if (message.parentMessageId != 0L) message.parentMessageId else message.messageId
val reply = UserMessageCreateParams("Thanks!").apply { parentMessageId = parentId }
channel.sendUserMessage(reply) { sent, e -> }

// List the replies of a parent message, starting at the parent's timestamp.
val threadParams = ThreadMessageListParams().apply {
    previousResultSize = 0
    nextResultSize = 30
}
message.getThreadedMessagesByTimestamp(message.createdAt, threadParams) { parent, replies, e -> }

// Keep the parent's reply count current.
SendbirdChat.addChannelHandler("threads", object : GroupChannelHandler() {
    override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}
    override fun onThreadInfoUpdated(channel: BaseChannel, threadInfoUpdateEvent: ThreadInfoUpdateEvent) {
        // Find the parent whose messageId == threadInfoUpdateEvent.targetMessageId,
        // then call parent.applyThreadInfoUpdateEvent(threadInfoUpdateEvent).
    }
})
```
- Only user and file messages can be threaded: a reply to a reply is rejected, and admin messages can't be replies or have replies. A message that is not a reply has `parentMessageId == 0`. When a reply is created, `onMessageReceived()` and `onThreadInfoUpdated()` fire; when a reply is deleted, only `onThreadInfoUpdated()` does. `replyToChannel` on the create params also sends the reply to the channel (default `false`; needs `parentMessageId`). (source: https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/create-a-message-thread, https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/list-replies-in-a-message-thread — reviewed 2026-10-11)
- `message.threadInfo` has `replyCount`, `mostRepliedUsers`, and `lastRepliedAt`. `MessageListParams.replyType` takes `ReplyType.NONE`, `ALL`, or `ONLY_REPLY_TO_CHANNEL`, and `MessagePayloadFilter` has `includeThreadInfo` and `includeParentMessageInfo`. When replies also show in the UIKit main list, see "Thread replies show up in the main UIKit message list" in knowledge/curated/android/cross-cutting/troubleshooting.md.
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `BaseMessageCreateParams` — `setParentMessageId(long)`, `setReplyToChannel(boolean)`; `UserMessageCreateParams(String)`; `BaseChannel.sendUserMessage(UserMessageCreateParams, UserMessageHandler)`; `BaseMessage` — `getMessageId()`, `getParentMessageId()`, `getCreatedAt()`, `getThreadInfo()`, `applyThreadInfoUpdateEvent(ThreadInfoUpdateEvent)`, `getThreadedMessagesByTimestamp(long, ThreadMessageListParams, ThreadedMessagesHandler)`; `ThreadMessageListParams()` with `BaseMessageListParams.setPreviousResultSize(int)` / `setNextResultSize(int)`; `ThreadedMessagesHandler.onResult(BaseMessage, List<BaseMessage>, SendbirdException)`; `ThreadInfo` — `getReplyCount()`, `getMostRepliedUsers()`, `getLastRepliedAt()`; `ThreadInfoUpdateEvent.getTargetMessageId()`; `BaseChannelHandler.onThreadInfoUpdated(BaseChannel, ThreadInfoUpdateEvent)`; `MessageListParams.setReplyType(ReplyType)`; `ReplyType` — `NONE`, `ALL`, `ONLY_REPLY_TO_CHANNEL`; `MessagePayloadFilter.setIncludeThreadInfo(boolean)`, `setIncludeParentMessageInfo(boolean)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.message/-base-message/index.html)

## Admin messages
A client SDK does not send admin messages: the docs list Sendbird Dashboard and the Chat Platform API as the ways to send one, and the SDK has no send method for them. They arrive like other messages, as `AdminMessage` (a `BaseMessage` subclass), through the message collection and the channel handler.
```kotlin
SendbirdChat.addChannelHandler("admin-notices", object : GroupChannelHandler() {
    override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {
        if (message is AdminMessage) {
            // An admin message: a system message sent without a sender.
        }
    }
})
```
- An admin message is a system message sent without a sender, and in a group channel the sender does not need to be a member. Delivery receipts, read receipts, message search, and message threading do not apply to admin messages (see also "`getUnreadMemberCount` is always 0 and `getReadMembers` is always empty" in knowledge/curated/android/cross-cutting/troubleshooting.md). (source: https://sendbird.com/docs/chat/sdk/v4/android/message/overview-message — the message type table, https://sendbird.com/docs/chat/sdk/v4/android/message/sending-a-message/send-an-admin-message — reviewed 2026-10-11)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `com.sendbird.android.message.AdminMessage extends BaseMessage`; `BaseChannelHandler.onMessageReceived(BaseChannel, BaseMessage)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.message/-admin-message/index.html)

## Custom type, data, and channel metadata
```kotlin
// A message's customType and data travel with the message.
val params = UserMessageCreateParams(MESSAGE).apply {
    customType = "order-update"
    data = """{"orderId":"1234"}"""
}
channel.sendUserMessage(params) { sent, e ->
    // receivers read sent?.customType and sent?.data
}

// Channel metadata: String-to-String pairs stored on the channel.
channel.createMetaData(mapOf("theme" to "dark")) { metaData, e -> }
channel.updateMetaData(mapOf("theme" to "light")) { metaData, e -> }   // updates existing keys, adds new ones
channel.getMetaData(listOf("theme")) { metaData, e -> }
val cachedMetaData: Map<String, String> = channel.cachedMetaData        // no server call
```
- `customType` subclassifies messages and is useful for searching or filtering; `data` carries any extra string. Channel metadata (`Map<String, String>`) stores extra information on the channel, such as a background color or a description. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/categorizing-messages/categorize-messages-by-custom-type, https://sendbird.com/docs/chat/sdk/v4/android/channel/managing-channel-metadata/manage-channel-metadata — reviewed 2026-10-11)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `BaseMessageCreateParams` — `setCustomType(String)`, `setData(String)`; `BaseMessage` — `getCustomType()`, `getData()`; `BaseChannel` — `createMetaData(Map, MetaDataHandler)`, `updateMetaData(Map, MetaDataHandler)`, `getMetaData(Collection, MetaDataHandler)`, `deleteMetaData(String, CompletionHandler)`, `getCachedMetaData()`; `MetaDataHandler.onResult(Map, SendbirdException)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-base-channel/index.html)

## Update the user profile
```kotlin
val profile = UserUpdateParams().apply {
    nickname = NICKNAME
    profileImageUrl = PROFILE_URL      // or profileImageFile to upload the image
}
SendbirdChat.updateCurrentUserInfo(profile) { e ->
    if (e != null) return@updateCurrentUserInfo
    // redraw the profile
}
```
- Updates the current user's nickname and profile image. An uploaded profile image can be a JPG, JPEG, or PNG file of up to 5 MB. (source: https://sendbird.com/docs/chat/sdk/v4/android/user/retrieving-and-updating-user-information/update-user-profile — reviewed 2026-10-11)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `UserUpdateParams()` — `setNickname(String)`, `setProfileImageUrl(String)`, `setProfileImageFile(File)`; `SendbirdChat.updateCurrentUserInfo(UserUpdateParams, CompletionHandler)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.params/-user-update-params/index.html)

## Reactions
```kotlin
channel.addReaction(message, ":+1:") { reactionEvent, e -> }
channel.deleteReaction(message, ":+1:") { reactionEvent, e -> }
```
Both are on `BaseChannel`, so they work for group and open channels identically. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.channel.BaseChannel`)

## Typing indicator (group channels)
```kotlin
channel.startTyping()
// ...
channel.endTyping()
```
Handle the incoming signal via `GroupChannelHandler.onTypingStatusUpdated(channel)`; read who's typing from `channel.getTypingUsers()`. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.channel.GroupChannel`, `com.sendbird.android.handler.GroupChannelHandler`)

## Read status
```kotlin
channel.markAsRead { e -> }                       // this channel only
SendbirdChat.markAsReadAll { e -> }                // every joined group channel
```
`markAsRead(CompletionHandler)` is on `GroupChannel`; `SendbirdChat.markAsReadAll(CompletionHandler)` is static. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.channel.GroupChannel`, `com.sendbird.android.SendbirdChat`)

## Unread counts
```kotlin
// one channel
val unread: Int = channel.unreadMessageCount

// every group channel the user joined
SendbirdChat.getTotalUnreadMessageCount(handler = UnreadMessageCountHandler { groupChannelCount, feedChannelCount, e ->
    if (e != null) return@UnreadMessageCountHandler
    // show `groupChannelCount` on the app badge or tab
})

// live updates: register once after connect
SendbirdChat.addUserEventHandler("unread-badge", object : UserEventHandler() {
    override fun onFriendsDiscovered(users: List<User>) {}
    override fun onTotalUnreadMessageCountChanged(unreadMessageCount: UnreadMessageCount) { /* refresh badge */ }
})
```
- `getTotalUnreadMessageCount` takes `params` first (with a default), so pass the handler by name: `handler = ...`. A positional handler does not compile. `UserEventHandler` is abstract: `onFriendsDiscovered` must be implemented. Filters: the `getTotalUnreadMessageCount(GroupChannelTotalUnreadMessageCountParams, UnreadMessageCountHandler)` overload. The `CountHandler` overloads and `onTotalUnreadMessageCountChanged(Int, Map)` are deprecated since 4.6.0. `markAsRead(handler)` (see Read status) resets a channel's count.
- `onTotalUnreadMessageCountChanged()` is turned off by default; the app owner must contact Sendbird to enable it. Until then, do not rely on it for the badge: refresh with `getTotalUnreadMessageCount` instead (for example after `markAsRead` or when the screen resumes). (source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler — reviewed 2026-10-06)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel.getUnreadMessageCount()`; `SendbirdChat.getTotalUnreadMessageCount(UnreadMessageCountHandler)` and `(GroupChannelTotalUnreadMessageCountParams, UnreadMessageCountHandler)`; `UnreadMessageCountHandler.onResult(int, int, SendbirdException)`; `CountHandler` overloads carry `Deprecated` ("As of 4.6.0, replaced with … UnreadMessageCountHandler", `javap -v`); `SendbirdChat.addUserEventHandler(String, UserEventHandler)`; abstract `UserEventHandler.onFriendsDiscovered(List<User>)`, `onTotalUnreadMessageCountChanged(UnreadMessageCount)` — verified 2026-10-05; example compiled with Kotlin against `sendbird-chat` 4.36.5 on 2026-10-06)
- The total counts unread messages in all group channels the user joined; it can be filtered by channel custom type or super-channel type. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/retrieving-unread-count-in-a-group-channel/unread-messages-in-all-channels — reviewed 2026-10-05)

## Hide or archive a channel
```kotlin
groupChannel.hide(false, true) { e -> }    // hidePreviousMessages = false, allowAutoUnhide = true: returns on a new message
groupChannel.hide(false, false) { e -> }   // allowAutoUnhide = false: archived until unhide()
groupChannel.unhide { e -> }
val isArchived = groupChannel.hiddenState == HiddenState.HIDDEN_PREVENT_AUTO_UNHIDE

val archivedQuery = GroupChannel.createMyGroupChannelListQuery(
    GroupChannelListQueryParams().apply { hiddenChannelFilter = HiddenChannelFilter.HIDDEN_PREVENT_AUTO_UNHIDE }
)
```
- `allowAutoUnhide = true` hides the channel until a new message arrives; `false` archives it until `unhide()` is called. `hidePreviousMessages = true` stops showing the messages sent before hiding (default `false`). (source: https://sendbird.com/docs/chat/sdk/v4/android/channel/managing-channels/hide-or-archive-a-group-channel — reviewed 2026-10-11)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel` — `hide(boolean, boolean, CompletionHandler)`, `unhide(CompletionHandler)`, `getHiddenState()`; `com.sendbird.android.channel.HiddenState` — `UNHIDDEN`, `HIDDEN_ALLOW_AUTO_UNHIDE`, `HIDDEN_PREVENT_AUTO_UNHIDE`; `com.sendbird.android.channel.query.HiddenChannelFilter`; `GroupChannelListQueryParams.setHiddenChannelFilter(HiddenChannelFilter)` — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html)

## Moderation (ban, mute, block, freeze)
```kotlin
// Operators only: check `groupChannel.myRole == Role.OPERATOR` first.
// Note the order: description comes BEFORE seconds on Android.
groupChannel.banUser("USER_ID", "Spam", 600) { e -> if (e != null) return@banUser }  // removed for 600 s
groupChannel.unbanUser("USER_ID") { e -> }
groupChannel.muteUser("USER_ID", "Flooding", 600) { e -> }   // stays in the channel, cannot send
groupChannel.unmuteUser("USER_ID") { e -> }
groupChannel.freeze { e -> }     // while frozen, only operators can send
groupChannel.unfreeze { e -> }

// Any user: block another user
SendbirdChat.blockUser("USER_ID") { blockedUser, e -> }
SendbirdChat.unblockUser("USER_ID") { e -> }

// Moderation events
SendbirdChat.addChannelHandler("moderation", object : GroupChannelHandler() {
    override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}   // abstract, required
    override fun onUserBanned(channel: BaseChannel, restrictedUser: RestrictedUser) {}
    override fun onUserMuted(channel: BaseChannel, restrictedUser: RestrictedUser) {}
    override fun onChannelFrozen(channel: BaseChannel) {}
    override fun onChannelUnfrozen(channel: BaseChannel) {}
})
```
- Ban, mute, and freeze are operator actions. A banned user is removed from the channel and can rejoin after the set time; a muted user stays in the channel and can read but not send. While a group channel is frozen only operators can send; open channels are frozen only through the Chat API or the dashboard, not the SDK. (source: https://sendbird.com/docs/chat/sdk/v4/android/user/moderating-a-user/ban-and-unban-a-user, https://sendbird.com/docs/chat/sdk/v4/android/user/moderating-a-user/mute-and-unmute-a-user, https://sendbird.com/docs/chat/sdk/v4/android/channel/moderating-a-channel/freeze-and-unfreeze-a-channel — reviewed 2026-10-06)
- Blocking: in a 1-to-1 group channel the blocker no longer receives the blocked user's messages or notifications; in a 1-to-N channel messages may still show depending on the chat UI, and by default notifications from the blocked user are not delivered (Sendbird can turn them on for individual channels on request). (source: https://sendbird.com/docs/chat/sdk/v4/android/user/moderating-a-user/block-and-unblock-other-members — reviewed 2026-10-06)
- State and lists: `isFrozen`, `myMutedState` (`MutedState.MUTED` / `UNMUTED`), `SendbirdChat.createBlockedUserListQuery(BlockedUserListQueryParams)`. `muteUser(userId, handler)` without a time also exists; every call has a `User`-taking overload.
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel.banUser(String, String, int, CompletionHandler)`, `unbanUser(String, CompletionHandler)`, `muteUser(String, String, int, CompletionHandler)` and `muteUser(String, CompletionHandler)`, `unmuteUser(String, CompletionHandler)`, `freeze(CompletionHandler)`, `unfreeze(CompletionHandler)`, `getMyRole()`, `getMyMutedState()`; `BaseChannel.isFrozen()`; `SendbirdChat.blockUser(String, UserHandler)`, `unblockUser(String, CompletionHandler)`, `createBlockedUserListQuery(BlockedUserListQueryParams)`; `BaseChannelHandler.onUserBanned`, `onUserMuted`, `onChannelFrozen`, `onChannelUnfrozen`; `Role.OPERATOR`, `MutedState.MUTED`; no `Deprecated` attribute on any of them (`javap -v`) — verified 2026-10-06)

## Invite members and manage operators
```kotlin
// `groupChannel` is a GroupChannel
groupChannel.invite(listOf("USER_ID")) { e -> }
groupChannel.addOperators(listOf("USER_ID")) { e -> }      // operators can mute, ban, and freeze
groupChannel.removeOperators(listOf("USER_ID")) { e -> }   // stays a member
```
- A private group channel can be joined only by invitation from a member. Whether a new member sees messages sent before the invite is an app setting, on by default. (source: https://sendbird.com/docs/chat/sdk/v4/android/channel/inviting-users-to-a-group-channel/invite-users-as-members, https://sendbird.com/docs/chat/sdk/v4/android/channel/managing-operators/register-and-remove-operators — reviewed 2026-10-07)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel.invite(List<String>, CompletionHandler)`, `BaseChannel.addOperators(Collection<String>, CompletionHandler)`, `removeOperators(Collection<String>, CompletionHandler)` — verified 2026-10-07)

## Pinned messages
```kotlin
groupChannel.pinMessage(message.messageId) { e -> }
groupChannel.unpinMessage(message.messageId) { e -> }
val pinnedIds: List<Long> = groupChannel.pinnedMessageIds

val pinnedQuery = SendbirdChat.createPinnedMessageListQuery(
    PinnedMessageListQueryParams(ChannelType.GROUP, groupChannel.url)
)
pinnedQuery.next { pinned, e ->
    val messages = pinned?.map { it.message } ?: emptyList()   // PinnedMessage.message
}
```
- Up to 10 messages can be pinned per channel by default. Group channels support pinning except ephemeral channels; Supergroup channels do not. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/managing-pinned-messages-in-group-channels/pin-a-message — reviewed 2026-10-07)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `BaseChannel.pinMessage(long, CompletionHandler)`, `unpinMessage(long, CompletionHandler)`, `getPinnedMessageIds()`; `SendbirdChat.createPinnedMessageListQuery(PinnedMessageListQueryParams)`; `PinnedMessageListQueryParams(ChannelType, String)`; `PinnedMessageListQuery.next(PinnedMessagesHandler)`; `PinnedMessage.getMessage()` — verified 2026-10-07)

## Search messages
```kotlin
val searchQuery = SendbirdChat.createMessageSearchQuery(
    MessageSearchQueryParams(keyword = "refund", channelUrl = groupChannel.url, limit = 20)  // drop channelUrl to search every joined channel
)
searchQuery.next { messages, e -> }   // call again while searchQuery.hasNext
```
- Searches group channel messages. Punctuation and special characters are ignored when indexing; `AND` and `OR` (uppercase) combine terms; a term shorter than two characters matches exactly only. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/searching-messages-in-a-group-channel/search-messages-by-a-keyword — reviewed 2026-10-07)
- `keyword` and `channelUrl` are constructor parameters (no setters). (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `SendbirdChat.createMessageSearchQuery(MessageSearchQueryParams)`; `MessageSearchQueryParams` constructor, `getKeyword()`, `getChannelUrl()`, `setLimit(int)`; `MessageSearchQuery.next(BaseMessagesHandler)`, `getHasNext()` — verified 2026-10-07)

## Filter the channel list by name
```kotlin
val listQuery = GroupChannel.createMyGroupChannelListQuery(
    GroupChannelListQueryParams().apply { channelNameContainsFilter = "support" }
)
listQuery.next { channels, e -> }
```
- (source: https://sendbird.com/docs/chat/sdk/v4/android/channel/searching-channels/search-group-channels-by-name-url-or-other-filters — reviewed 2026-10-07; `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel.createMyGroupChannelListQuery(GroupChannelListQueryParams)`, `GroupChannelListQueryParams.setChannelNameContainsFilter(String)` — verified 2026-10-07)

## Read receipts for a message
```kotlin
val unreadCount = groupChannel.getUnreadMemberCount(message)           // 0 = every member has read it
val readers = groupChannel.getReadMembers(message, false)              // false = exclude the current user
```
- (source: https://sendbird.com/docs/chat/sdk/v4/android/message/managing-read-status-in-a-group-channel/get-read-status — reviewed 2026-10-07; `sendbird-chat` 4.36.5 AAR, `javap -public`: `GroupChannel.getUnreadMemberCount(BaseMessage)`, `getReadMembers(BaseMessage, boolean)`, `getUnreadMembers(BaseMessage, boolean)` — verified 2026-10-07)

## Connection state and reconnection
```kotlin
SendbirdChat.addConnectionHandler("connection-banner", object : ConnectionHandler {
    override fun onConnected(userId: String) {}
    override fun onDisconnected(userId: String) {}
    override fun onReconnectStarted() { /* show "Reconnecting..." */ }
    override fun onReconnectSucceeded() { /* hide the banner and refresh */ }
    override fun onReconnectFailed() { /* offer a manual retry */ }
})
```
- The SDK reconnects by itself after a network drop; these callbacks only report it. All five methods are abstract and must be implemented. (source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-connection-event-handlers/add-or-remove-a-connection-event-handler — reviewed 2026-10-07)
- (source: `sendbird-chat` 4.36.5 AAR, `javap -public`: `SendbirdChat.addConnectionHandler(String, ConnectionHandler)`; `ConnectionHandler` — `onConnected(String)`, `onDisconnected(String)`, `onReconnectStarted()`, `onReconnectSucceeded()`, `onReconnectFailed()` — verified 2026-10-07)

## Handle incoming events without a collection
```kotlin
SendbirdChat.addChannelHandler("UNIQUE_HANDLER_ID", object : GroupChannelHandler() {
    override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) { }
    override fun onTypingStatusUpdated(channel: GroupChannel) { }
})
// SendbirdChat.removeChannelHandler("UNIQUE_HANDLER_ID") on cleanup
```
`onMessageReceived` is not called on the device that sent the message: the docs list its notified devices as every device with the channel open in the foreground except the sender's. Your own sent message comes back through the send call's handler instead. (source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-channel-event-handlers/add-or-remove-a-channel-event-handler)
`GroupChannelHandler` extends `BaseChannelHandler`, whose `onMessageReceived(channel, message)` is abstract (must override); `GroupChannelHandler` itself adds optional overrides such as `onTypingStatusUpdated` and `onUserMarkedRead`. Add/remove exactly once per active screen — a handler added without a matching remove leaks. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` (`addChannelHandler`/`removeChannelHandler`), `com.sendbird.android.handler.BaseChannelHandler`, `com.sendbird.android.handler.GroupChannelHandler`)

## Pitfalls
- Initialize once in `Application.onCreate()`, not per Activity.
- App ID read from BuildConfig/secret, not a hard-coded literal; session/access tokens are secrets — never hard-code or log.
- Every `GroupChannelCollection` / `MessageCollection` and every `addChannelHandler` call must be paired with `dispose()` / `removeChannelHandler(id)` when the owning screen is destroyed, or the SDK keeps delivering events to a dead component.

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message
- Auth/session: knowledge/curated/android/products/auth.md
- Errors: knowledge/curated/android/cross-cutting/errors.md
- Push (handler, logout order): knowledge/curated/android/cross-cutting/push.md
