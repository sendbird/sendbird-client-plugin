<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- status: populated -->
# ios chat

> Verified against sendbird.com/docs (Chat SDK v4 iOS getting-started) and the public mirror `sendbird/sendbird-chat-sdk-ios`. Init and connect rebuilt against 4.39.10 with xcodebuild on 2026-09-08. Channel list, message list, reactions, typing, read status, and delegates below verified against the real `SendbirdChatSDK.swiftinterface` extracted from a pinned 4.39.10 SPM build (xcodegen + xcodebuild against `https://github.com/sendbird/sendbird-chat-sdk-ios`, verified 2026-09-29). Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message

## Overview
Sendbird Chat is the foundation product (auth/session live here). Install the SDK, initialize once at launch, connect a user, then operate on channels (group or open) to send/receive messages.

## Install (SPM — prefer over CocoaPods)
- SPM package `https://github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, `from: "4.0.0"`. Do NOT use `sendbird-chat-ios-spm` (legacy v3). See `knowledge/curated/ios/setup.md`.

## Initialize (once, at launch)
```swift
import SendbirdChatSDK

let params = InitParams(applicationId: APP_ID, isLocalCachingEnabled: true, needsSynchronous: false)
SendbirdChat.initialize(params: params,
    migrationStartHandler: { },
    completionHandler: { error in /* ready when error == nil */ })
```
(source: sendbird.com/docs chat v4 ios getting-started; build-verified)

## Connect a user (auth)
```swift
SendbirdChat.connect(userId: USER_ID) { user, error in
    guard let user = user, error == nil else { return }
    // connected
}
```
For authenticated apps pass a session token / access token — see `knowledge/curated/ios/products/auth.md`. (source: sendbird.com/docs chat v4 ios getting-started; build-verified)

## Create and list group channels
```swift
let params = GroupChannelCreateParams()
params.userIds = [otherUserId]
params.isDistinct = true   // reuse the existing 1:1 channel instead of creating a duplicate

GroupChannel.createChannel(params: params) { channel, error in
    guard let channel = channel, error == nil else { return }
}
```
`GroupChannel.createChannel(params:completionHandler:)` is a class method; the completion is `GroupChannelHandler = (GroupChannel?, SBError?) -> Void`. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 2602 `createChannel(params:completionHandler:)`, line 3624 `GroupChannelHandler` typealias)

For a live-updating channel list, use a `GroupChannelCollection`:
```swift
let query = GroupChannel.createMyGroupChannelListQuery { params in
    params.includeEmptyChannel = true
}
guard let collection = SendbirdChat.createGroupChannelCollection(query: query) else { return }
collection.delegate = self   // conform to GroupChannelCollectionDelegate

collection.loadMore { channels, error in
    // first page; call loadMore again while collection.hasNext
}
// collection.dispose() when the screen is dismissed
```
```swift
extension MyViewController: GroupChannelCollectionDelegate {
    func channelCollection(_ collection: GroupChannelCollection, context: ChannelContext, addedChannels: [GroupChannel]) {}
    func channelCollection(_ collection: GroupChannelCollection, context: ChannelContext, updatedChannels: [GroupChannel]) {}
    func channelCollection(_ collection: GroupChannelCollection, context: ChannelContext, deletedChannelURLs: [String]) {}
}
```
`GroupChannel.createMyGroupChannelListQuery(paramsBuilder:)` builds the query; `SendbirdChat.createGroupChannelCollection(query:)` creates the collection; `collection.delegate`, `.loadMore(completionHandler:)`, `.hasNext`, `.channelList`, and `.dispose()` are all on `GroupChannelCollection`. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 2730 `createMyGroupChannelListQuery(paramsBuilder:)`, line 6585 `createGroupChannelCollection(query:)`, lines 1426-1459 `GroupChannelCollection`, lines 1460-1464 `GroupChannelCollectionDelegate`)

## Send a message
```swift
channel.sendUserMessage(MESSAGE) { message, error in
    guard let message = message, error == nil else { return }
    // sent
}
```

Chat 4.39.11 adds `initialUserMessage` to `InitConversationParams`. When `GroupChannel.initConversation(params:)` creates a conversation, that text becomes the user's first message. The public release note verifies the property and behavior but does not publish the full initializer signature, so inspect the installed 4.39.11 interface before constructing the params. (source: sendbird/sendbird-chat-sdk-ios CHANGELOG.md 4.39.11, reviewed 2026-09-22)

`channel` is a `GroupChannel` (or `OpenChannel`). (source: sendbird.com/docs chat v4 ios getting-started)

### Send a file message
```swift
channel.sendFileMessage(params: FileMessageCreateParams(file: fileData)) { message, error in
    guard let message = message, error == nil else { return }
}
```
`FileMessageCreateParams` also takes `fileURL` (pre-uploaded), `fileName`, `thumbnailSizes`, `mimeType`. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 2418 `FileMessageCreateParams`, `BaseChannel.sendFileMessage(params:completionHandler:)` line 513)

## Update and delete a message
```swift
let params = UserMessageUpdateParams(message: "Edited text")
channel.updateUserMessage(messageId: message.messageId, params: params) { updated, error in
    guard let updated = updated, error == nil else { return }
    // replace the old message in your list with `updated`
}

channel.deleteMessage(message) { error in
    guard error == nil else { return }
}
```
- File messages: `updateFileMessage(messageId:params:completionHandler:)` with `FileMessageUpdateParams`. Deleting by id: `deleteMessage(messageId:completionHandler:)`.
- Other members are told through `BaseChannelDelegate`: `channel(_:didUpdate:)` and `channel(_:messageWasDeleted:)` (the deleted message's id).
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11) `extension BaseChannel` line 482: `updateUserMessage(messageId:params:completionHandler:)` 506, `updateFileMessage` 524, `deleteMessage(_:completionHandler:)` 542, `deleteMessage(messageId:completionHandler:)` 545; `UserMessageUpdateParams.init(message:)` 7219; `BaseMessage.messageId` 989; `BaseChannelDelegate` 867, `channel(_:didUpdate:)` 869, `channel(_:messageWasDeleted:)` 879 — verified 2026-10-05)
- A user can update or delete messages they sent; channel operators can update or delete any message in the channel. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-a-message/update-a-message, https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-a-message/delete-a-message — reviewed 2026-10-05)

## List and receive messages
For a message list screen, use a `MessageCollection`:
```swift
let params = MessageListParams()
let collection = SendbirdChat.createMessageCollection(channel: channel, startingPoint: Int64(Date().timeIntervalSince1970 * 1000), params: params)
collection.delegate = self   // conform to MessageCollectionDelegate

collection.startCollection(initPolicy: .cacheAndReplaceByApi, cacheResultHandler: { messages, error in
    // render cached messages immediately
}, apiResultHandler: { messages, error in
    // replace with the server's authoritative page
})

if collection.hasPrevious {
    collection.loadPrevious { messages, error in }
}
// collection.dispose() when the screen is dismissed
```
```swift
extension MyViewController: MessageCollectionDelegate {
    func messageCollection(_ collection: MessageCollection, context: MessageContext, channel: GroupChannel, addedMessages: [BaseMessage]) {}
    func messageCollection(_ collection: MessageCollection, context: MessageContext, channel: GroupChannel, updatedMessages: [BaseMessage]) {}
    func messageCollection(_ collection: MessageCollection, context: MessageContext, channel: GroupChannel, deletedMessages: [BaseMessage]) {}
}
```
`SendbirdChat.createMessageCollection(channel:startingPoint:params:)`, `.delegate`, `.startCollection(initPolicy:cacheResultHandler:apiResultHandler:)`, `.hasPrevious` / `.hasNext`, `.loadPrevious(completionHandler:)` / `.loadNext(completionHandler:)`, and `.dispose()` are all on `MessageCollection`. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 6587 `createMessageCollection`, lines 4011-4050 `MessageCollection`, lines 4055-4066 `MessageCollectionDelegate`)

## Reactions
```swift
channel.addReaction(with: message, key: ":+1:") { reactionEvent, error in }
channel.deleteReaction(with: message, key: ":+1:") { reactionEvent, error in }
```
Both are on `BaseChannel`, so they work for group and open channels identically. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 693 `addReaction(with:key:completionHandler:)`, line 696 `deleteReaction(with:key:completionHandler:)`)

## Typing indicator (group channels)
```swift
channel.startTyping()
// ...
channel.endTyping()
```
Handle the incoming signal via `GroupChannelDelegate.channelDidUpdateTypingStatus(_:)`; read who's typing from `channel.getTypingUsers()`. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 2713 `startTyping()`, line 2714 `endTyping()`, `channelDidUpdateTypingStatus` in `GroupChannelDelegate`)

## Read status
```swift
channel.markAsRead(completionHandler: nil)                 // this channel only
SendbirdChat.markAsReadAll(completionHandler: nil)          // every joined group channel
```
`markAsRead(completionHandler:)` is on `GroupChannel`; `SendbirdChat.markAsReadAll(completionHandler:)` / `SendbirdChat.markAsRead(channelURLs:completionHandler:)` are static. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 2699 `GroupChannel.markAsRead`, line 6506 `markAsReadAll`, line 6509 `markAsRead(channelURLs:)`)

## Unread counts
```swift
// one channel
let unread: UInt = channel.unreadMessageCount

// every group channel the user joined
SendbirdChat.getTotalUnreadMessageCount { count, error in
    guard error == nil else { return }
    // show `count` on the app badge or tab
}

// live updates: register once after connect
final class UnreadObserver: NSObject, UserEventDelegate {
    func didUpdateTotalUnreadMessageCount(unreadMessageCount: UnreadMessageCount) { /* refresh badge */ }
}
SendbirdChat.addUserEventDelegate(observer, identifier: "unread-badge")   // keep `observer` alive
```
- Filters: `SendbirdChat.getTotalUnreadMessageCountWithFeed(params:completionHandler:)` with `GroupChannelTotalUnreadMessageCountParams` (`channelCustomTypesFilter`, `superChannelFilter`); its handler gets group and feed channel counts. `markAsRead(completionHandler:)` (see Read status) resets a channel's count.
- Do not use `GroupChannel.getTotalUnreadMessageCount(...)` (marked `@available(*, unavailable)` on the line above each declaration; does not compile), `SendbirdChat.getTotalUnreadMessageCount(params:completionHandler:)` (deprecated in 4.6.0), or `SendbirdChat.add(_:identifier:)` (deprecated in 4.0.12).
- The per-custom-type counts in this event (`totalCountByCustomType` in the docs) are turned off by default; the app owner must contact Sendbird to enable them. (source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-user-event-delegates/add-or-remove-a-user-event-delegate — reviewed 2026-10-06)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `GroupChannel` line 2826, `unreadMessageCount` 2870; `SendbirdChat` 6295 — `static getTotalUnreadMessageCount(completionHandler:)` 6494, `getTotalUnreadMessageCountWithFeed(params:completionHandler:)` 6498, deprecated `(params:completionHandler:)` 6496-6497; `CountHandler` 3643, `UnreadMessageCountHandler` 3644; `GroupChannelTotalUnreadMessageCountParams` 3306; unavailable `GroupChannel` overloads 2814-2823; `UserEventDelegate` 7160 — `didUpdateTotalUnreadMessageCount(unreadMessageCount:)` 7168; `SendbirdChat.addUserEventDelegate(_:identifier:)` 6387 (deprecated `add(_:identifier:)` 6385-6386) — verified 2026-10-05)
- The total counts unread messages in all group channels the user joined; it can be filtered by channel custom type or super-channel type. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/retrieving-unread-count-in-a-group-channel/unread-messages-in-all-channels — reviewed 2026-10-05)

## Moderation (ban, mute, block, freeze)
```swift
// Operators only: check `channel.myRole == .operator` first. `channel` is a GroupChannel.
channel.banUser(userId: "USER_ID", seconds: 600, description: "Spam") { error in
    guard error == nil else { return }   // banned: removed from the channel for 600 s
}
channel.unbanUser(userId: "USER_ID") { error in }
channel.muteUser(userId: "USER_ID", seconds: 600, description: nil) { error in }   // stays in the channel, cannot send
channel.unmuteUser(userId: "USER_ID") { error in }
channel.freeze { error in }     // while frozen, only operators can send
channel.unfreeze { error in }

// Any user: block another user
SendbirdChat.blockUserId("USER_ID") { blockedUser, error in }
SendbirdChat.unblockUserId("USER_ID") { error in }

// Moderation events (register with SendbirdChat.addChannelDelegate(_:identifier:))
final class ModerationObserver: NSObject, GroupChannelDelegate {
    func channel(_ channel: BaseChannel, userWasBanned user: RestrictedUser) {}
    func channel(_ channel: BaseChannel, userWasMuted user: RestrictedUser) {}
    func channelWasFrozen(_ channel: BaseChannel) {}
    func channelWasUnfrozen(_ channel: BaseChannel) {}
}
```
- Ban, mute, and freeze are operator actions. A banned user is removed from the channel and can rejoin after `seconds`; a muted user stays in the channel and can read but not send. While a group channel is frozen only operators can send; open channels are frozen only through the Chat API or the dashboard, not the SDK. (source: https://sendbird.com/docs/chat/sdk/v4/ios/user/moderating-a-user/ban-and-unban-a-user, https://sendbird.com/docs/chat/sdk/v4/ios/user/moderating-a-user/mute-and-unmute-a-user, https://sendbird.com/docs/chat/sdk/v4/ios/channel/moderating-a-channel/freeze-and-unfreeze-a-channel — reviewed 2026-10-06)
- Blocking: in a 1-to-1 group channel the blocker no longer receives the blocked user's messages or notifications; in a 1-to-N channel messages may still show depending on the chat UI, and by default notifications from the blocked user are not delivered (Sendbird can turn them on for individual channels on request). (source: https://sendbird.com/docs/chat/sdk/v4/ios/user/moderating-a-user/block-and-unblock-other-members — reviewed 2026-10-06)
- State and lists: `channel.isFrozen`, `channel.myMutedState` (`.muted` / `.unmuted`), `channel.createBannedUserListQuery()` and `channel.createMutedUserListQuery()` (both return an optional), `SendbirdChat.createBlockedUserListQuery()`. The `User`-taking overloads (`banUser(_:seconds:description:completionHandler:)`, `blockUser(_:completionHandler:)`, ...) do the same thing.
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `BaseChannel` extension 482 — `banUser(userId:seconds:description:completionHandler:)` 621, `unbanUser(userId:completionHandler:)` 627, `muteUser(userId:seconds:description:completionHandler:)` 654, `unmuteUser(userId:completionHandler:)` 657, `createBannedUserListQuery()` 699, `createMutedUserListQuery()` 711, `isFrozen` 819; `BaseChannelDelegate` 867 — `userWasMuted` 871, `userWasBanned` 873, `channelWasFrozen`/`channelWasUnfrozen` 875-876; `GroupChannel` extension 2597 — `freeze(completionHandler:)` 2651, `unfreeze(completionHandler:)` 2654, `myRole` 2903, `myMutedState` 2906; `SendbirdChat` 6295 — `createBlockedUserListQuery()` 6361, `addChannelDelegate(_:identifier:)` 6376, `blockUserId(_:completionHandler:)` 6574, `unblockUserId(_:completionHandler:)` 6580; `Role` 7274, `MutedState` 7287; none marked deprecated — verified 2026-10-06)

## Handle incoming events without a collection
```swift
SendbirdChat.addChannelDelegate(self, identifier: "UNIQUE_HANDLER_ID")
// SendbirdChat.removeChannelDelegate(forIdentifier: "UNIQUE_HANDLER_ID") on cleanup

extension MyController: GroupChannelDelegate {
    func channel(_ channel: BaseChannel, didReceive message: BaseMessage) {}
    func channelWasChanged(_ channel: BaseChannel) {}
}
```
`GroupChannelDelegate` extends `BaseChannelDelegate` (which declares `channel(_:didReceive:)`) and adds group-specific callbacks such as `channel(_:userDidMarkAsRead:)` and `channelDidUpdateTypingStatus(_:)`. Add/remove exactly once per mounted screen — a delegate added without a matching remove leaks. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 6372 `addChannelDelegate(_:identifier:)`, line 6373 `removeChannelDelegate(forIdentifier:)`, lines 867-880 `BaseChannelDelegate`, lines 2968-2985 `GroupChannelDelegate`)

## Pitfalls
- Initialize exactly once (app launch). Re-initializing per screen is an anti-pattern — see `knowledge/curated/ios/cross-cutting/performance.md`.
- App ID is not a secret but read it from config/env, not hard-coded literals.
- Session tokens/access tokens are secrets — never hard-code or log them.
- Every `GroupChannelCollection` / `MessageCollection` and every `addChannelDelegate` call must be paired with `dispose()` / `removeChannelDelegate(forIdentifier:)` when the owning screen is dismissed, or the SDK keeps delivering events to a dead view controller.

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message
- Auth/session: knowledge/curated/ios/products/auth.md
- Errors: knowledge/curated/ios/cross-cutting/errors.md
