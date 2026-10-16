<!-- status: populated -->
# templates/ios/swiftui/chat

`ChatSession.swift` — an `ObservableObject` wrapping the verified Chat SDK calls so SwiftUI
views can observe connection state. The SDK calls are identical to the build-verified UIKit-host
template (`templates/ios/uikit/chat/InitConnect.swift`); only the SwiftUI/Combine wrapper is new.

The feature models below do the same for the most requested message features. Each wraps the calls of the matching
UIKit-host file in `templates/ios/uikit/chat/`, and `tools/templates/compile-check-ios.sh` builds all of them against the
pinned and the latest `SendbirdChatSDK` SPM release.

Sources: (source: knowledge/curated/ios/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html) (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html)

## Files
- `ChatSession.swift` — init, connect, send, connection state.
- `FileUploadModel.swift` — send an image or file with upload progress, cancel, retry a failed file message (UIKit-host counterpart: `FileMessageSender.swift`).
- `MessageActionsModel.swift` — edit and delete your own messages, and receive other members' edits and deletes as a Combine stream (`MessageEditing.swift`).
- `UnreadCountModel.swift` — total unread count for a tab badge, live updates, per-channel count, mark as read (`UnreadCount.swift`).
- `ChannelActivityModel.swift` — typing indicator and read receipts for one conversation (`TypingAndReadReceipts.swift`).

## Splice steps
1. Add the Chat SDK via SPM: `github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, from `4.0.0`.
2. Copy `ChatSession.swift` into your app target.
3. Use the one shared session: initialize it at launch, show it from the app root, and connect from the app's
   own sign-in code (see `knowledge/curated/ios/hosts/swiftui.md` "Start the session from the app's sign-in"):
   ```swift
   @main
   struct MyApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(ChatSession.shared)
                   .task { ChatSession.shared.initialize() }
           }
       }
   }

   // In the app's sign-in success handler, whatever type or thread it runs on:
   Task { @MainActor in ChatSession.shared.connect(userId: userId) }
   ```
4. Read state in any view: `@EnvironmentObject var chat: ChatSession` → `chat.isConnected`, `chat.currentUser`.
5. Provide the App ID through the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting
   (see `knowledge/curated/ios/setup.md` "App ID"; do not hard-code). Authenticated
   apps connect with a token: `SendbirdChat.connect(userId:authToken:)`.

## Feature models
Copy only the files the app needs. The per-conversation models take the loaded group channel; create them in the
conversation view's initializer (`_upload = StateObject(wrappedValue: FileUploadModel(channel: channel))`) so they live
as long as the screen.

### Send an image or file (`FileUploadModel.swift`)
1. Load the picked item's bytes (for example `PhotosPicker` → `loadTransferable(type: Data.self)`) and call
   `upload.send(data, fileName: "photo.jpg", mimeType: "image/jpeg")`.
2. Show `ProgressView(value: progress)` while `upload.progress` is set; a Cancel button calls `upload.cancel()`.
3. While `upload.failedMessage` is set, show a Retry button that calls `upload.retry()`.

### Edit and delete messages (`MessageActionsModel.swift`)
1. Create `MessageActionsModel(channel:)`; call `start()` in `.onAppear` and `stop()` in `.onDisappear` (skip both
   when the list already uses a `MessageCollection`).
2. In the message `.contextMenu`, show Edit and Delete only when `actions.isMine(message)`; they call
   `actions.edit(userMessage, newText:)` and `actions.delete(message)`.
3. Apply `.onReceive(actions.changes) { change in ... }` to replace (`.updated`) or remove (`.deleted`) rows.

### Unread counts (`UnreadCountModel.swift`)
1. After `ChatSession.shared.connect` succeeds, call `UnreadCountModel.shared.start()`; call `stop()` on sign-out.
2. Show it on the tab: `.badge(unread.total)` with `@ObservedObject var unread = UnreadCountModel.shared`.
3. Call `refresh()` when the channel list appears (the docs say the live event can be turned off for an app); call
   `markRead(channel)` when a conversation opens. Per row: `unread.unreadCount(of: channel)`.

### Typing indicator and read receipts (`ChannelActivityModel.swift`)
1. Create `ChannelActivityModel(channel:)`; call `start()` in `.onAppear` (it also marks the channel read) and `stop()` in `.onDisappear`.
2. `.onChange(of: draft) { activity.textDidChange($0) }` on the text field; call `activity.sent()` after sending.
3. Show "… is typing" from `activity.typingNames`. Call `activity.markRead()` when a new message arrives on screen.
4. For your own messages, show a read mark when `activity.unreadMemberCount(of: message) == 0`, and read
   `activity.readReceiptsVersion` in the same view so it redraws when someone reads.

## Notes
- Message UI: Chat SDK is headless. For prebuilt SwiftUI chat screens use `SendbirdSwiftUI`
  (`templates/ios/swiftui/uikit`, which also notes how to wrap the UIViewController-based Sendbird UIKit).
- `@MainActor` keeps `@Published` updates on the main thread; SDK completion handlers hop back via `Task { @MainActor in ... }`,
  and delegate methods are `nonisolated` for the same reason.
