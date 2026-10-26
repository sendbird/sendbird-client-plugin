<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- status: populated -->
# ios chat

> Verified against sendbird.com/docs (Chat SDK v4 iOS getting-started) and the public mirror `sendbird/sendbird-chat-sdk-ios`. Init and connect rebuilt against 4.39.10 with xcodebuild on 2026-09-08. Channel list, message list, reactions, typing, read status, and delegates below verified against the real `SendbirdChatSDK.swiftinterface` extracted from a pinned 4.39.10 SPM build (xcodegen + xcodebuild against `https://github.com/sendbird/sendbird-chat-sdk-ios`, verified 2026-09-29). The connect-ordering, local caching, thread, admin message, metadata, profile, and hide/archive sections were checked on 2026-10-11 against the public interface of the 4.39.11 release xcframework (checksum matched the release `Package.swift`) and the linked Chat v4 iOS docs pages. Cite each symbol; do not add API from memory.
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

The docs describe what these options do:
- `needsSynchronous` is `false` by default, so the local cache migration runs asynchronously and initialization takes less time. When you use local caching, set it to `true` to finish the migration before the app is fully launched.
- If initialization fails with `isLocalCachingEnabled` set to `true`, the SDK keeps working and sets it to `false`. To use local caching again, clear the database with `SendbirdChat.clearCachedData(completionHandler:)` and initialize again with caching on.
- When another class or method calls Chat SDK functions while initialization may still be running, use `SendbirdChat.executeOrWaitForInitialization(executeHandler:)`. It runs the handler immediately if the SDK is initialized, and otherwise waits for initialization to complete.

```swift
import SendbirdChatSDK

SendbirdChat.executeOrWaitForInitialization {
    // Runs once initialization has completed.
}
```
(source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message (sections "Local caching", "Synchronous initialization", and "Initialization dependency management"); `SendbirdChat.executeOrWaitForInitialization(executeHandler:)` line 6316, `clearCachedData(completionHandler:)` line 6596, `InitParams.needsSynchronous` line 3691 in the SendbirdChatSDK 4.39.11 `.swiftinterface`; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html; community context: https://github.com/sendbird/sendbird-chat-sdk-ios/discussions/34)

## Connect a user (auth)
```swift
SendbirdChat.connect(userId: USER_ID) { user, error in
    guard let user = user, error == nil else { return }
    // connected
}
```
For authenticated apps pass a session token / access token — see `knowledge/curated/ios/products/auth.md`. (source: sendbird.com/docs chat v4 ios getting-started; build-verified)

## Call APIs only after connect completes
Apart from initializing, the SDK must be connected before almost every call. Start calls that need the server from the `connect` completion, or check the connection state first and wait for the connection delegate.
```swift
// App launch or push open: initialize, connect, then call APIs that need the server.
SendbirdChat.connect(userId: USER_ID) { user, error in
    guard user != nil, error == nil else { return }   // not connected: do not call server APIs yet
    SendbirdChat.getTotalUnreadMessageCount { count, error in /* badge */ }
}

// Code that can run before connect finishes (a push handler, another screen):
if SendbirdChat.getConnectState() == .open {
    SendbirdChat.getTotalUnreadMessageCount { count, error in /* badge */ }
}
// Otherwise wait for ConnectionDelegate.didConnect(userId:) or didSucceedReconnection()
// (register with SendbirdChat.addConnectionDelegate(_:identifier:), see "Connection state and reconnection").
```
- Apart from initializing, connect before calling almost every Chat SDK method; a call made without a connection returns `.connectionRequired` (800101). (source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication — reviewed 2026-10-11)
- `didConnect(userId:)` fires when the SDK has connected with the given user ID; `didSucceedReconnection()` fires after an automatic reconnection. (source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-connection-delegates/add-or-remove-a-connection-delegate — reviewed 2026-10-11)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11, sha256-verified release xcframework): `SendbirdChat.connect(userId:completionHandler:)` 6318, `getConnectState()` 6357, `getTotalUnreadMessageCount(completionHandler:)` 6494, `addConnectionDelegate(_:identifier:)` 6368; `WebSocketConnectionState` 7344 (`.open` 7346); `ConnectionDelegate` 1694 — `didSucceedReconnection()` 1696, `didConnect(userId:)` 1698; `ChatError.connectionRequired` 1540 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html)

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
<!-- compile: receiver SnippetChannelListHost -->
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

### Upload progress and resending a failed file message
Pass a `progressHandler` to `sendFileMessage(params:progressHandler:completionHandler:)` to show upload progress. It receives the request ID, the bytes sent since the last call, the total bytes sent so far, and the total bytes to send. The class method `BaseChannel.cancelUploadingFileMessage(requestId:completionHandler:)` cancels an upload that is still in progress.

To retry a failed file message, check `isResendable(in:)` and call `resendFileMessage(_:binaryData:completionHandler:)` (or the overload with `progressHandler:`). Pass only a failed message. The API reference says that when the failed message already has a file URL, the SDK only resends the message command and ignores the data; when it has no file URL, the upload itself failed, and the SDK uploads `binaryData` first. With a `MessageCollection`, the final state arrives in `messageCollection(_:context:channel:updatedMessages:)`, where `context.sendingStatus` is `.succeeded` or `.failed` (see "Local caching and offline messages" below).

```swift
import Foundation
import SendbirdChatSDK

func sendPhoto(_ data: Data, in channel: GroupChannel, onProgress: @escaping (Double) -> Void) {
    let params = FileMessageCreateParams(file: data)
    params.fileName = "photo.jpg"
    params.mimeType = "image/jpeg"
    channel.sendFileMessage(params: params, progressHandler: { _, _, totalBytesSent, totalBytesExpectedToSend in
        guard totalBytesExpectedToSend > 0 else { return }
        onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }, completionHandler: { message, error in
        // error == nil: sent. Otherwise `message` is the failed message to offer for retry.
    })
}

func retry(_ failed: FileMessage, originalData: Data?, in channel: GroupChannel) {
    guard failed.isResendable(in: channel) else { return }
    channel.resendFileMessage(failed, binaryData: originalData) { message, error in
        // error == nil: sent. Otherwise it is still failed.
    }
}
```
(source: https://sendbird.com/docs/chat/sdk/v4/ios/message/sending-a-message/track-file-upload-progress-using-a-handler; https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html (`resendFileMessage(_:binaryData:completionHandler:)`: failed messages only, file URL vs. binary data); https://sendbird.com/docs/chat/sdk/v4/ios/local-caching/using-message-collection/message-collection; `SendbirdChatSDK.swiftinterface` (4.39.11): `extension BaseChannel` 482 — `sendFileMessage(params:progressHandler:completionHandler:)` 517, `resendFileMessage(_:binaryData:completionHandler:)` 528, `resendFileMessage(_:binaryData:progressHandler:completionHandler:)` 532, `cancelUploadingFileMessage(requestId:completionHandler:)` 539 (a class method); `extension BaseMessage` 934 — `isResendable(in:)` 941 (the no-argument `isResendable()` at 939 is deprecated); `MultiProgressHandler` 3604)

### Send a file from an app extension (Share Extension)
The API reference says that an app extension that uploads a file message must call `SendbirdChat.setSharedContainerIdentifier(_:)`, which sets the `sharedContainerIdentifier` of the `URLSessionConfiguration` the SDK uses for its background session. Apple's `sharedContainerIdentifier` documentation says the value must identify a container shared between the app extension and its containing app.

```swift
import Foundation
import SendbirdChatSDK

func sendSharedImage(_ imageData: Data, toChannelURL channelURL: String, completion: @escaping (SBError?) -> Void) {
    SendbirdChat.initialize(params: InitParams(applicationId: APP_ID), migrationStartHandler: nil) { error in
        if let error { return completion(error) }
        SendbirdChat.setSharedContainerIdentifier("group.com.example.myapp")   // your App Group
        SendbirdChat.connect(userId: USER_ID, authToken: AUTH_TOKEN) { user, error in
            guard user != nil else { return completion(error) }
            GroupChannel.getChannel(url: channelURL) { channel, error in
                guard let channel else { return completion(error) }
                let params = FileMessageCreateParams(file: imageData)
                params.fileName = "shared.png"
                params.mimeType = "image/png"
                channel.sendFileMessage(params: params) { _, error in completion(error) }
            }
        }
    }
}
```
(source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (`setSharedContainerIdentifier(_:)`, marked Important for app extensions that upload file messages); `SendbirdChat.setSharedContainerIdentifier(_:)` line 6545, `initialize(params:migrationStartHandler:completionHandler:)` line 6309, `connect(userId:authToken:completionHandler:)` line 6321, `GroupChannel.getChannel(url:completionHandler:)` line 2616, `FileMessageCreateParams.fileName` and `mimeType` lines 2428 and 2434 in the SendbirdChatSDK 4.39.11 `.swiftinterface`; source: https://developer.apple.com/documentation/foundation/urlsessionconfiguration/sharedcontaineridentifier; community context: https://github.com/sendbird/sendbird-chat-sdk-ios/discussions/62)

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
<!-- compile: receiver SnippetMessageListHost -->
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

To draw a row, read the text from `message.message` (`String`), the sender from `message.sender` (`Sender?`, a `User` with `userId`, `nickname`, and `profileURL`), and the time from `message.createdAt` (`Int64`). `SendbirdChat.getCurrentUser()` returns the connected `User?`; compare its `userId` with `message.sender?.userId` to tell your own messages from others'. Unwrap `sender` instead of force-unwrapping it (see Pitfalls). (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `BaseMessage` 982 — `message` 990, `sender` 1005, `createdAt` 1028; `SendbirdChat.getCurrentUser()` 6564; `Sender` 6771; `User` 7043 — `userId` 7047, `nickname` 7050, `profileURL` 7060 — verified 2026-10-23)

## Local caching and offline messages
Local caching keeps group channels and messages on the device, so the channel list and chat view built with the collections above also work offline. Turn it on or off once, in `InitParams`:
```swift
let cacheConfig = LocalCacheConfig()
cacheConfig.maxSize = 256                                 // MB; default 256, minimum 64
cacheConfig.clearOrder = .messageCollectionAccessedAt     // default: clear channels whose chat view was opened longest ago
let params = InitParams(applicationId: APP_ID, isLocalCachingEnabled: true, localCacheConfig: cacheConfig)   // false turns caching off
SendbirdChat.initialize(params: params, migrationStartHandler: { }, completionHandler: { error in })
```
```swift
final class ChatScreenEvents: NSObject, MessageCollectionDelegate {
    func messageCollection(_ collection: MessageCollection, context: MessageContext, channel: GroupChannel, updatedMessages: [BaseMessage]) {
        switch context.sendingStatus {
        case .succeeded: break   // a pending message reached the server (also after an auto resend)
        case .failed: break      // not resent automatically
        default: break
        }
    }
    func didDetectHugeGap(_ collection: MessageCollection) {
        collection.dispose()     // more than 300 messages missing: create a new collection
    }
}

func outbox(_ collection: MessageCollection) -> (waiting: [BaseMessage], failed: [BaseMessage]) {
    (collection.pendingMessages, collection.failedMessages)
}
```
- Default: `isLocalCachingEnabled` is `false`. With caching, `LocalCacheConfig.maxSize` defaults to 256 MB (values under 64 MB become 64 MB). The SDK checks the cache size on the first `connect` after initialization and, past the limit, clears cached messages in `clearOrder`. `SendbirdChat.clearCachedData(completionHandler:)` erases everything, `clearCachedMessages(channelURL:completionHandler:)` one channel's messages, and `getCachedDataSize()` reports the size. (source: https://sendbird.com/docs/chat/sdk/v4/ios/local-caching/overview-local-caching, https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication — reviewed 2026-10-11)
- Reconnecting after a long time offline: the SDK fills small gaps through changelog sync. When more than 300 messages are missing from the cache, it calls `didDetectHugeGap(_:)`; dispose the collection and create a new one instead of paging through the gap. Contact Sendbird support to change the 300 threshold. (source: https://sendbird.com/docs/chat/sdk/v4/ios/local-caching/using-message-collection/message-collection — reviewed 2026-10-11)
- `loadPrevious(completionHandler:)` loads the previous page and passes its messages to the completion handler; the docs call it only when `hasPrevious` is true. (source: https://sendbird.com/docs/chat/sdk/v4/ios/local-caching/using-message-collection/message-collection — reviewed 2026-10-11)
- Messages sent while offline, with local caching: a user message that could not go out because the WebSocket connection was lost is kept as **pending** and resent automatically when the connection comes back (auto resend). A file message waits the same way when the network is down. When the resend succeeds, `messageCollection(_:context:channel:updatedMessages:)` reports it with `context.sendingStatus == .succeeded`. A send that fails for another reason, such as `ChatError.networkError` or `ChatError.ackTimeout`, is reported as **failed** and is not resent automatically. A pending message older than three days is marked failed when the connection returns. (source: https://sendbird.com/docs/chat/sdk/v4/ios/local-caching/overview-local-caching — reviewed 2026-10-11)
- `SendbirdChat.disconnect` also clears the local cache; `disconnectWebSocket` keeps it (see knowledge/curated/ios/products/auth.md).
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `InitParams.init(applicationId:isLocalCachingEnabled:localCacheConfig:logLevel:appVersion:)` 3693; `LocalCacheConfig` 3734 — `maxSize` 3735, `clearOrder` 3739, `init(isEncryptionEnabled:enableAutoResend:)` 3748; `CachedDataClearOrder.messageCollectionAccessedAt` 1363; `MessageCollection` 4015 — `succeededMessages` 4031, `pendingMessages` 4034, `failedMessages` 4037, `loadPrevious(completionHandler:)` 4045; `MessageCollectionDelegate` 4059 — `updatedMessages` 4061, `didDetectHugeGap(_:)` 4065; `MessageContext.sendingStatus` 4087; `MessageSendingStatus` 4524; `SendbirdChat.clearCachedData(completionHandler:)` 6596, `clearCachedMessages(channelURL:completionHandler:)` 6599, `getCachedDataSize()` 6601 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/MessageCollection.html)

## Message threads
A reply carries its parent's message ID. Threads are one level deep, so a reply to a reply must point at the thread's root message.
```swift
// Reply in a thread.
let parentId = message.parentMessageId != 0 ? message.parentMessageId : message.messageId
let reply = UserMessageCreateParams(message: "Thanks!")
reply.parentMessageId = parentId
channel.sendUserMessage(params: reply) { sent, error in }

// List the replies of a parent message, starting at the parent's timestamp.
let threadParams = ThreadedMessageListParams()
threadParams.previousResultSize = 0
threadParams.nextResultSize = 30
threadParams.includeParentMessageInfo = true
message.getThreadedMessages(timestamp: message.createdAt, params: threadParams) { parentMessage, replies, error in
    let list = replies ?? []  // the handler's array is optional
}
```
```swift
// Keep the parent's reply count current (register with SendbirdChat.addChannelDelegate(_:identifier:)).
final class ThreadObserver: NSObject, GroupChannelDelegate {
    func channel(_ channel: BaseChannel, didReceive message: BaseMessage) {}
    func channel(_ channel: BaseChannel, didUpdateThreadInfo threadInfoUpdateEvent: ThreadInfoUpdateEvent) {
        // Find the parent whose messageId == threadInfoUpdateEvent.targetMessageId, then call parent.apply(threadInfoUpdateEvent).
    }
}
```
- Only user and file messages can be threaded: a reply to a reply is rejected, and admin messages can't be replies or have replies. A message that is not a reply has `parentMessageId == 0`. When a reply is created, `channel(_:didReceive:)` and `channel(_:didUpdateThreadInfo:)` fire; when a reply is deleted, only `channel(_:didUpdateThreadInfo:)` does. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/create-a-message-thread, https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/list-replies-in-a-message-thread — reviewed 2026-10-11)
- In a thread screen that is a `UIViewController`, name the root message property `rootMessage` (or anything but `parent`): `UIViewController` already has `parent`, and a stored `parent` of another type fails with "overriding property must be as accessible as its enclosing type". A thread screen on the UIKit or SwiftUI host can start from `templates/ios/uikit/chat/MessageThreads.swift` or `templates/ios/swiftui/chat/ThreadModel.swift`, which the template compile check builds. The handler's parameters are `parentMessage`, `messages`, and `error`, and the array is optional (`ThreadedMessageListHandler` 3629 in the source list below).
- `message.threadInfo` has `replyCount`, `mostRepliedUsers`, and `lastRepliedAt`. It is a non-optional `ThreadInfo` (a message without replies has `replyCount` 0), so `if let info = message.threadInfo` fails with "initializer for conditional binding must have Optional type, not 'ThreadInfo'"; read `message.threadInfo.replyCount` directly, as `MessageThreads.replyCount(of:)` and `ThreadModel.replyCount(of:)` in the templates do. On Android it is not nullable either; in JavaScript it is `ThreadInfo | null`. `MessageListParams` has `replyType` (`.none`, `.all`, `.onlyReplyToChannel`) and `includeThreadInfo`; when replies also show in the main list, see "Thread replies also show up in the main message list" in knowledge/curated/ios/cross-cutting/troubleshooting.md.
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `BaseMessageCreateParams.parentMessageId` 1226, `isReplyToChannel` 1227; `UserMessageCreateParams.init(message:)` 7205; `BaseChannel.sendUserMessage(params:completionHandler:)` 495; `BaseMessage` 982 — `messageId` 989, `createdAt` 1028, `parentMessageId` 1036, `threadInfo` 1039; `extension BaseMessage` 934 — `apply(_: ThreadInfoUpdateEvent)` 947, `getThreadedMessages(timestamp:params:completionHandler:)` 952; `ThreadedMessageListHandler` 3629; `ThreadedMessageListParams` 6858 — `previousResultSize` 6859, `nextResultSize` 6860, `includeParentMessageInfo` 6868; `ThreadInfo` 6841; `ThreadInfoUpdateEvent.targetMessageId` 6851; `BaseChannelDelegate.channel(_:didUpdateThreadInfo:)` 900; `MessageListParams.includeThreadInfo` 4191, `replyType` 4193; `ReplyType` 4559 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseMessage.html)

## Admin messages
A client SDK does not send admin messages: the docs list Sendbird Dashboard and the Chat Platform API as the ways to send one, and the SDK has no send method for them. They arrive like other messages, as `AdminMessage` (a `BaseMessage` subclass), through the message collection and the channel delegate.
```swift
final class NoticeObserver: NSObject, GroupChannelDelegate {
    func channel(_ channel: BaseChannel, didReceive message: BaseMessage) {
        if message is AdminMessage {
            // An admin message: a system message sent without a sender.
        }
    }
}
```
- An admin message is a system message sent without a sender, and in a group channel the sender does not need to be a member. Delivery receipts, message search, and message threading do not apply to admin messages. In the push payload, an admin message has `type` `ADMM`. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/overview-message, https://sendbird.com/docs/chat/sdk/v4/ios/message/sending-a-message/send-an-admin-message, https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials — reviewed 2026-10-11)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `AdminMessage : BaseMessage` 271; `BaseChannelDelegate.channel(_:didReceive:)` 868 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/AdminMessage.html)

## Custom type, data, and channel metadata
```swift
// A message's customType and data travel with the message.
let params = UserMessageCreateParams(message: MESSAGE)
params.customType = "order-update"
params.data = "{\"orderId\":\"1234\"}"
channel.sendUserMessage(params: params) { sent, error in
    // receivers read sent?.customType and sent?.data
}

// Channel metadata: String-to-String pairs stored on the channel.
channel.createMetaData(["theme": "dark"]) { metaData, error in }
channel.updateMetaData(["theme": "light"]) { metaData, error in }   // updates existing keys, adds new ones
channel.getMetaData(keys: ["theme"]) { metaData, error in }
let cachedMetaData = channel.getCachedMetaData()                   // no server call
```
- `customType` subclassifies messages and is useful for searching or filtering; `data` carries any extra string. Channel metadata stores extra information on the channel, such as a background color or a description; the SDK caches it after any create, read, update, or delete and when a channel list is fetched, and `getCachedMetaData()` reads that cache. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/categorizing-messages/categorize-messages-by-custom-type, https://sendbird.com/docs/chat/sdk/v4/ios/channel/managing-channel-metadata/manage-channel-metadata — reviewed 2026-10-11)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `BaseMessageCreateParams.data` 1196, `customType` 1197; `BaseMessage.data` 1058, `customType` 1061; `extension BaseChannel` 482 — `createMetaData(_:completionHandler:)` 599, `getMetaData(keys:completionHandler:)` 602, `updateMetaData(_:completionHandler:)` 608, `deleteMetaData(key:completionHandler:)` 611, `getCachedMetaData()` 616 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html)

## Update the user profile
```swift
let profile = UserUpdateParams()
profile.nickname = NICKNAME
profile.profileImageURL = PROFILE_URL      // or profileImageData to upload the image
SendbirdChat.updateCurrentUserInfo(params: profile, progressHandler: nil) { error in
    guard error == nil else { return }
    // redraw the profile
}
```
- Updates the current user's nickname and profile image. An uploaded profile image can be a JPG, JPEG, or PNG file of up to 5 MB. (source: https://sendbird.com/docs/chat/sdk/v4/ios/user/retrieving-and-updating-user-information/update-user-profile — reviewed 2026-10-11)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `UserUpdateParams` 7322 — `nickname` 7323, `profileImageURL` 7330, `profileImageData` 7334; `SendbirdChat.updateCurrentUserInfo(params:progressHandler:completionHandler:)` 6568 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/UserUpdateParams.html)

## Reactions
```swift
channel.addReaction(with: message, key: ":+1:") { reactionEvent, error in }
channel.deleteReaction(with: message, key: ":+1:") { reactionEvent, error in }
```
Both are on `BaseChannel`, so they work for group and open channels identically. (source: `SendbirdChatSDK.swiftinterface` (4.39.10) line 693 `addReaction(with:key:completionHandler:)`, line 696 `deleteReaction(with:key:completionHandler:)`)

To show who reacted, read each `Reaction`'s `key`, `count`, and `sampledUserIds` (or `sampledUserInfoList`). Do not use `userIds` or `getUserIds`: both are deprecated and renamed to `sampledUserIds`. (source: `SendbirdChatSDK.swiftinterface` (4.39.11 release xcframework, arm64 simulator) `final public class Reaction` line 6158: `key` 6159, `@available(*, deprecated, renamed: "sampledUserIds")` on `userIds` 6160-6161 and `getUserIds` 6164-6165, `sampledUserIds` 6171, `sampledUserInfoList` 6174, `count` 6177 — verified 2026-10-24)

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
- The iOS page names only the per-custom-type counts as off by default. The Android page differs and turns off its whole event by default, so the Android curated doc says so. (source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-user-event-delegates/add-or-remove-a-user-event-delegate ; https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler — reviewed 2026-10-16)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `GroupChannel` line 2826, `unreadMessageCount` 2870; `SendbirdChat` 6295 — `static getTotalUnreadMessageCount(completionHandler:)` 6494, `getTotalUnreadMessageCountWithFeed(params:completionHandler:)` 6498, deprecated `(params:completionHandler:)` 6496-6497; `CountHandler` 3643, `UnreadMessageCountHandler` 3644; `GroupChannelTotalUnreadMessageCountParams` 3306; unavailable `GroupChannel` overloads 2814-2823; `UserEventDelegate` 7160 — `didUpdateTotalUnreadMessageCount(unreadMessageCount:)` 7168; `SendbirdChat.addUserEventDelegate(_:identifier:)` 6387 (deprecated `add(_:identifier:)` 6385-6386) — verified 2026-10-05)
- The total counts unread messages in all group channels the user joined; it can be filtered by channel custom type or super-channel type. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/retrieving-unread-count-in-a-group-channel/unread-messages-in-all-channels — reviewed 2026-10-05)

## Hide or archive a channel
```swift
channel.hide(hidePreviousMessages: false, allowAutoUnhide: true) { error in }    // hidden; returns to the list when a new message arrives
channel.hide(hidePreviousMessages: false, allowAutoUnhide: false) { error in }   // archived; stays hidden until unhide
channel.unhide { error in }
let isArchived = channel.hiddenState == .hiddenPreventAutoUnhide

let archivedQuery = GroupChannel.createMyGroupChannelListQuery { params in
    params.channelHiddenStateFilter = .hiddenPreventAutoUnhide   // .hiddenOnly returns hidden and archived channels
}
```
- `allowAutoUnhide: true` hides the channel until a new message arrives; `false` archives it until `unhide` is called. `hidePreviousMessages: true` stops showing the messages sent before hiding (default `false`). (source: https://sendbird.com/docs/chat/sdk/v4/ios/channel/managing-channels/hide-or-archive-a-group-channel — reviewed 2026-10-11)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `extension GroupChannel` 2597 — `hide(hidePreviousMessages:allowAutoUnhide:completionHandler:)` 2693, `unhide(completionHandler:)` 2696; `GroupChannel.hiddenState` 2897; `GroupChannelHiddenState` 3440; `ChannelHiddenStateFilter` 3454; `GroupChannelListQueryParams.channelHiddenStateFilter` 3200 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html)

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

## Invite members and manage operators
```swift
// `channel` is a GroupChannel
channel.inviteUserIds(["USER_ID"]) { error in }
channel.addOperators(userIds: ["USER_ID"]) { error in }     // operators can mute, ban, and freeze
channel.removeOperators(userIds: ["USER_ID"]) { error in }  // stays a member
```
- A private group channel can be joined only by invitation from a member. Whether a new member sees messages sent before the invite is an app setting, on by default. (source: https://sendbird.com/docs/chat/sdk/v4/ios/channel/inviting-users-to-a-group-channel/invite-users-as-members, https://sendbird.com/docs/chat/sdk/v4/ios/channel/managing-operators/register-and-remove-operators — reviewed 2026-10-07)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `GroupChannel.inviteUserIds(_:completionHandler:)` 2666; `BaseChannel.addOperators(userIds:completionHandler:)` 663, `removeOperators(userIds:completionHandler:)` 666 — verified 2026-10-07)

## Pinned messages
```swift
channel.pinMessage(messageId: message.messageId) { error in }
channel.unpinMessage(messageId: message.messageId) { error in }
let pinnedIds = channel.pinnedMessageIds          // [Int64]?

let pinnedQuery = channel.createPinnedMessageListQuery { params in params.limit = 20 }
pinnedQuery?.loadNextPage { pinned, error in
    let messages = pinned?.compactMap { $0.message } ?? []   // PinnedMessage.message
}
```
- Up to 10 messages can be pinned per channel by default. Group channels support pinning except ephemeral channels; Supergroup channels do not. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-pinned-messages-in-group-channels/pin-a-message — reviewed 2026-10-07)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `BaseChannel.pinMessage(messageId:completionHandler:)` 551, `unpinMessage(messageId:completionHandler:)` 554, `createPinnedMessageListQuery(paramsBuilder:)` 755, `pinnedMessageIds` 825; `PinnedMessage.message` 5180; `PinnedMessageListQuery.loadNextPage(completionHandler:)` 5219; `PinnedMessageListQueryParams.limit` 5226 — verified 2026-10-07)

## Search messages
```swift
let searchQuery = SendbirdChat.createMessageSearchQuery { params in
    params.keyword = "refund"
    params.channelURL = channel.channelURL   // omit to search every joined group channel
    params.limit = 20
}
searchQuery.loadNextPage { messages, error in }  // call again while searchQuery.hasNext
```
- Searches group channel messages. Punctuation and special characters are ignored when indexing; `AND` and `OR` (uppercase) combine terms; a term shorter than two characters matches exactly only. (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/searching-messages-in-a-group-channel/search-messages-by-a-keyword — reviewed 2026-10-07)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `SendbirdChat.createMessageSearchQuery(builder:)` 6364; `MessageSearchQueryParams.keyword` 4384, `channelURL` 4391, `limit` 4398; `MessageSearchQuery.loadNextPage(completionHandler:)` 4326 — verified 2026-10-07)

## Filter the channel list by name
```swift
let listQuery = GroupChannel.createMyGroupChannelListQuery { params in
    params.channelNameContainsFilter = "support"
}
listQuery.loadNextPage { channels, error in }
```
- (source: https://sendbird.com/docs/chat/sdk/v4/ios/channel/searching-channels/search-group-channels-by-name-url-or-other-filters — reviewed 2026-10-07; `SendbirdChatSDK.swiftinterface` (4.39.11): `GroupChannel.createMyGroupChannelListQuery(paramsBuilder:)` 2730, `GroupChannelListQueryParams.channelNameContainsFilter` 3194 — verified 2026-10-07)

## Find users by nickname
```swift
let userQuery = SendbirdChat.createApplicationUserListQuery { params in
    params.nicknameStartsWithFilter = "Ja"
}
userQuery.loadNextPage { users, error in }
```
- The nickname filter matches the start of the nickname only; the other filters are user IDs and a metadata key with values. There is no filter for a word in the middle of a nickname, so autocomplete on any part of a name needs the app's own user index.
- (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/ApplicationUserListQueryParams.html — `nicknameStartsWithFilter` ; https://sendbird.com/docs/chat/sdk/v4/javascript/user/retrieving-users/retrieve-a-list-of-users-in-an-application — the same filter described as "nicknames start with the specified value" ; `SendbirdChatSDK.swiftinterface` (4.39.11): `SendbirdChat.createApplicationUserListQuery(paramsBuilder:)` 6359, `ApplicationUserListQueryParams.nicknameStartsWithFilter` 386, `ApplicationUserListQuery.loadNextPage(completionHandler:)` 353)

## Read receipts for a message
```swift
let unreadCount = channel.getUnreadMemberCount(message)        // 0 = every member has read it
let readers = channel.getReadMembers(message: message, includeAllMembers: false)
let statuses = channel.getReadStatus(with: false)              // [userId: ReadStatus], excludes the current user
```
- (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-read-status-in-a-group-channel/get-read-status — reviewed 2026-10-07; `SendbirdChatSDK.swiftinterface` (4.39.11): `GroupChannel.getUnreadMemberCount(_:)` 2707, `getReadMembers(message:includeAllMembers:)` 2708, `getReadStatus(with:)` 2712 — verified 2026-10-07)

## Connection state and reconnection
```swift
final class ConnectionObserver: NSObject, ConnectionDelegate {
    func didStartReconnection() { /* show "Reconnecting..." */ }
    func didSucceedReconnection() { /* hide the banner and refresh */ }
    func didFailReconnection() { /* offer a manual retry */ }
}
let observer = ConnectionObserver()   // keep a strong reference
SendbirdChat.addConnectionDelegate(observer, identifier: "connection-banner")
```
- The SDK reconnects by itself after a network drop; these callbacks only report it. `didConnect(userId:)` and `didDisconnect(userId:)` are also available. (source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-connection-delegates/add-or-remove-a-connection-delegate — reviewed 2026-10-07)
- (source: `SendbirdChatSDK.swiftinterface` (4.39.11): `ConnectionDelegate` 1694 — `didStartReconnection` 1695, `didSucceedReconnection` 1696, `didFailReconnection` 1697; `SendbirdChat.addConnectionDelegate(_:identifier:)` 6368 — verified 2026-10-07)

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
- `PollCreateParams` has no anonymous-vote setting in the SDK. The iOS "Create a poll" guide still lists an `isAnonymous` parameter, but `PollCreateParams` in 4.39.11 has only `title`, `data`, `optionTexts`, `allowUserSuggestion`, `allowMultipleVotes`, and `closeAt`, and its API reference page has no such property either. Code that sets `isAnonymous` does not compile. (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/PollCreateParams.html) (source: SendbirdChatSDK 4.39.11 `.swiftinterface` lines 5299–5305) (source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-polls/create-a-poll)
- `BaseMessage.sender` is `Sender?`. Unwrap it (`guard let sender = message.sender`) instead of force-unwrapping, and give the row a fallback when it is `nil`. (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseMessage.html) (source: SendbirdChatSDK 4.39.11 `.swiftinterface` line 1005)
- Every `GroupChannelCollection` / `MessageCollection` and every `addChannelDelegate` call must be paired with `dispose()` / `removeChannelDelegate(forIdentifier:)` when the owning screen is dismissed, or the SDK keeps delivering events to a dead view controller. In SwiftUI, "dismissed" is not `.onDisappear`: that also runs when a pushed screen covers the list; see `knowledge/curated/ios/hosts/swiftui.md` "Releasing a collection when its screen goes away".

## Related
- Getting started: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message
- Auth/session: knowledge/curated/ios/products/auth.md
- Errors: knowledge/curated/ios/cross-cutting/errors.md
- Push (token per signed-in user, logout order, payload): knowledge/curated/ios/cross-cutting/push.md
