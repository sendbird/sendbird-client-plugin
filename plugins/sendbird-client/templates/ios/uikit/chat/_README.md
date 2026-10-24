<!-- status: populated -->
# templates/ios/uikit/chat

Chat init + connect + send on iOS (UIKit), plus the most requested message features. From sendbird.com/docs (chat v4 ios
getting-started, verified 2026-06-09) and the SendbirdChatSDK release `.swiftinterface` (4.39.10 and 4.39.11).
**Build-verified**: `tools/templates/compile-check-ios.sh` builds every file here against the pinned and the latest
`SendbirdChatSDK` SPM release (xcodebuild BUILD SUCCEEDED, generic iOS).

Sources: (source: knowledge/curated/ios/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html) (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html) (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html)

## Files
- `InitConnect.swift` — `SendbirdChatBootstrap.initialize()` / `.connect(userId:)` / `.send(_:to:)`.
- `PushRegistration.swift` — register and unregister the APNs device token.
- `FileMessageSender.swift` — send an image or file with upload progress, cancel an upload, resend a failed file message.
- `MessageEditing.swift` — edit and delete your own messages (`MessageEditor`), and hear about other members' edits and deletes (`MessageChangeObserver`).
- `UnreadCount.swift` — total unread count for a tab or app badge, live updates, per-channel count, mark as read (`UnreadCountObserver`).
- `TypingAndReadReceipts.swift` — typing indicator and read receipts for one conversation (`ChannelActivityObserver`).
- `MessageThreads.swift` — thread replies: load a root message's replies, send a reply, hear new replies (`MessageThreads`, `ThreadReplyObserver`).

## How to splice
1. Add the SPM package `https://github.com/sendbird/sendbird-chat-sdk-ios` (product `SendbirdChatSDK`, from 4.0.0) — prefer SPM, do not add CocoaPods.
2. Call `SendbirdChatBootstrap.initialize()` once in `application(_:didFinishLaunchingWithOptions:)`.
3. Call `.connect(userId:)` after login. Read the App ID from the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting (see `knowledge/curated/ios/setup.md` "App ID") — never hard-code; tokens are secrets.

The feature files below assume a connected user and a loaded group channel. Copy only the files the app needs; each
one stands alone.

### Send an image or file (`FileMessageSender.swift`)
1. Get the bytes from the picker (for example `PHPickerViewController` → `loadDataRepresentation`) and call
   `FileMessageSender.send(data, fileName: "photo.jpg", mimeType: "image/jpeg", in: channel, onProgress: { ... }, completion: { message, error in ... })`.
2. Keep the returned pending message and the bytes until `completion` runs. Show `onProgress` (0.0...1.0) on the
   pending row; `FileMessageSender.cancel(pending)` stops the upload.
3. When `completion` gets an error, keep the failed message and offer Retry:
   `FileMessageSender.resend(failed, originalData: data, in: channel, onProgress: ..., completion: ...)`.
4. With a `MessageCollection`, the final state also arrives in the collection delegate (`context.sendingStatus`).

### Edit and delete messages (`MessageEditing.swift`)
1. In the message long-press menu, show Edit and Delete only when `MessageEditor.isMine(message)`.
2. Edit: `MessageEditor.edit(userMessage, newText: text, in: channel) { updated, error in ... }`, then replace the row with `updated`.
3. Delete: `MessageEditor.delete(message, in: channel) { error in ... }`, then remove the row.
4. Without a `MessageCollection`, create `MessageChangeObserver(channelURL:onUpdated:onDeleted:)`, call `start()` in
   `viewDidLoad` and `stop()` when the screen goes away, so other members' edits and deletes show up too.

### Unread counts (`UnreadCount.swift`)
1. After connect, keep one `UnreadCountObserver { total in ... }` (for example on the app delegate) and call `start()`;
   set the tab badge in the closure. Call `stop()` on sign-out.
2. Call `refresh()` when the channel list appears: the docs say the live event can be turned off for an app.
3. Per row: `UnreadCountObserver.unreadCount(of: channel)`. When a conversation opens, call `observer.markRead(channel)`.

### Typing indicator and read receipts (`TypingAndReadReceipts.swift`)
1. In the conversation screen create `ChannelActivityObserver(channelURL:onTypingChanged:onReadReceiptsChanged:)`;
   `start()` in `viewDidLoad`, `stop()` when the screen goes away.
2. From the text view's change handler call `ChannelActivityObserver.textDidChange(text, in: channel)`; after sending call `channel.endTyping()`.
3. Show "… is typing" from `onTypingChanged`. Call `ChannelActivityObserver.markRead(channel)` when the screen shows and when a new message arrives.
4. For your own messages, show a read mark when `ChannelActivityObserver.unreadMemberCount(of: message, in: channel) == 0`,
   and reload visible rows on `onReadReceiptsChanged`.

### Thread replies (`MessageThreads.swift`)
1. Open the thread screen with the root message (`parentMessageId == 0`); `MessageThreads.rootId(of:)` gives its ID when the user tapped a reply.
   In the thread view controller call the property `rootMessage`, never `parent`: `UIViewController` already has `parent`,
   and a stored `parent` of another type does not build.
2. `MessageThreads.loadReplies(of: rootMessage) { replies, error in ... }`; send with `MessageThreads.reply(to:text:in:completion:)`
   and show the returned pending message.
3. `ThreadReplyObserver(channelURL:rootMessageId:onReply:)`: `start()` in `viewDidLoad`, `stop()` when the screen goes away.

## Variations (see knowledge/curated/ios/products/chat.md, all cited)
- Authenticated: `SendbirdChat.connect(userId:authToken:) { ... }`.
- Channels: load/create a `GroupChannel` before `send(_:to:)` (see docs for `GroupChannelCreateParams`).
- File messages from a Share Extension need `SendbirdChat.setSharedContainerIdentifier(_:)` (chat.md "Send a file from an app extension").
- Prebuilt screens that already include all of the above: Sendbird UIKit (`templates/ios/uikit/uikit`).
