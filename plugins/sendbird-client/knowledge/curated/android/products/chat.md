<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- status: populated -->
# android chat

> Verified against sendbird.com/docs (Chat SDK v4 Android getting-started, verified 2026-06-09) and the public mirror `sendbird/sendbird-chat-sdk-android`. The templates compiled against 4.36.4 in GitHub Actions run 34187419379 on 2026-09-08; 4.36.5 is an internal-only patch (auto-resend handling; no public API change per CHANGELOG) re-verified against the changelog on 2026-09-28. Channel list, message list, reactions, typing, read status, and handlers below verified against the real `sendbird-chat-4.36.5.aar` (downloaded from `https://repo.sendbird.com/public/maven`, decompiled with `javap -public`, verified 2026-09-29). Cite each symbol; do not add API from memory.
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

## Connect a user (auth)
```kotlin
SendbirdChat.connect(userId) { user, e ->
    if (user != null) { /* connected */ }
}
```
Callback receives `(User?, SendbirdException?)`. Authenticated apps pass a session/access token — see `knowledge/curated/android/products/auth.md`. (source: sendbird.com/docs chat v4 android getting-started)

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
    override fun onChannelDeleted(context: GroupChannelContext, deletedChannelUrl: String) { }
    override fun onHugeGapDetected() { }
}
val collectionParams = MessageCollectionCreateParams(channel, MessageListParams(), System.currentTimeMillis(), messageHandler)
val collection = SendbirdChat.createMessageCollection(collectionParams)

collection.initialize(MessageCollectionInitPolicy.CACHE_AND_REPLACE_BY_API, object : MessageCollectionInitHandler {
    override fun onCacheResult(messages: List<BaseMessage>?, e: SendbirdException?) { /* render cached messages immediately */ }
    override fun onApiResult(messages: List<BaseMessage>?, e: SendbirdException?) { /* replace with the server's authoritative page */ }
})

if (collection.hasPrevious) {
    collection.loadPrevious { messages, e -> }
}
// collection.dispose() when the screen is destroyed
```
`MessageCollectionCreateParams(channel, params, startingPoint, handler)` bundles the setup; `SendbirdChat.createMessageCollection(params)` is the factory. `.initialize(policy, handler)`, `.hasPrevious` / `.hasNext`, `.loadPrevious(handler)` / `.loadNext(handler)`, and `.dispose()` are on `BaseMessageCollection`. Unlike the JS/iOS SDKs, `MessageCollectionHandler`'s add/update/delete callbacks always pass the full `BaseMessage` list — there is no separate deprecated message-id array. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` (`createMessageCollection`), `com.sendbird.android.params.MessageCollectionCreateParams`, `com.sendbird.android.collection.BaseMessageCollection`, `com.sendbird.android.handler.BaseMessageCollectionHandler`, `com.sendbird.android.handler.MessageCollectionInitHandler`)

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

## Handle incoming events without a collection
```kotlin
SendbirdChat.addChannelHandler("UNIQUE_HANDLER_ID", object : GroupChannelHandler() {
    override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) { }
    override fun onTypingStatusUpdated(channel: GroupChannel) { }
})
// SendbirdChat.removeChannelHandler("UNIQUE_HANDLER_ID") on cleanup
```
`GroupChannelHandler` extends `BaseChannelHandler`, whose `onMessageReceived(channel, message)` is abstract (must override); `GroupChannelHandler` itself adds optional overrides such as `onTypingStatusUpdated` and `onUserMarkedRead`. Add/remove exactly once per active screen — a handler added without a matching remove leaks. (source: `sendbird-chat-sdk-android` 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` (`addChannelHandler`/`removeChannelHandler`), `com.sendbird.android.handler.BaseChannelHandler`, `com.sendbird.android.handler.GroupChannelHandler`)

## Pitfalls
- Initialize once in `Application.onCreate()`, not per Activity.
- App ID read from BuildConfig/secret, not a hard-coded literal; session/access tokens are secrets — never hard-code or log.
- Every `GroupChannelCollection` / `MessageCollection` and every `addChannelHandler` call must be paired with `dispose()` / `removeChannelHandler(id)` when the owning screen is destroyed, or the SDK keeps delivering events to a dead component.

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message
- Auth/session: knowledge/curated/android/products/auth.md
- Errors: knowledge/curated/android/cross-cutting/errors.md
