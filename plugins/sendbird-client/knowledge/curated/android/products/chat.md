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
