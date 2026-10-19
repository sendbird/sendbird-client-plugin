<!-- status: populated -->
# templates/android/view/chat

Chat init + connect + send on Android, plus the most requested message features. Code from sendbird.com/docs (chat v4
android getting-started, verified 2026-06-09); every import path verified against the public
samples `sendbird-chat-sample-android`. The feature files are verified with
`javap` on the `sendbird-chat` 4.36.4 and 4.36.5 AARs. `tools/templates/compile-check-android.sh` compiles every file
here against the pinned and the latest SDK set.

Sources: (source: knowledge/curated/android/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html)

## Files
- `InitConnect.kt` — `ChatApplication` init + `connectUser(userId)` + `send(text, channel)`.
- `PushRegistration.kt` — the FCM push handler. Apply the `com.google.gms.google-services` Gradle plugin only when `app/google-services.json` exists (see `knowledge/curated/android/cross-cutting/push.md` "Setup checklist"); an unconditional apply fails the build when the file is missing. Never create a placeholder file. The customer downloads `google-services.json` from their Firebase project; list that in `manualSteps`.
- `FileMessageSender.kt` — send an image or file with upload progress, cancel an upload, resend a failed file message.
- `MessageEditing.kt` — edit and delete your own messages (`MessageEditor`), and hear about other members' edits and deletes (`MessageChangeListener`).
- `UnreadCount.kt` — total unread count for a tab or launcher badge, live updates, per-channel count, mark as read (`UnreadCountTracker`).
- `TypingAndReadReceipts.kt` — typing indicator and read receipts for one conversation (`ChannelActivityTracker`).

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven` in `settings.gradle`;
   `implementation("com.sendbird.sdk:sendbird-chat:4.36.3")` in `build.gradle`.
2. Set `ChatApplication` as `android:name` in `AndroidManifest.xml`.
3. Call `connectUser(...)` after login. App ID from BuildConfig/secret — never hard-code; tokens are secrets.

The feature files below assume a connected user and a loaded group channel. Copy only the files the app needs, and
change their `package` line to the app's package.

### Send an image or file (`FileMessageSender.kt`)
1. Copy the picked content `Uri` (for example from `ActivityResultContracts.PickVisualMedia`) into a `File` in `cacheDir`.
2. `FileMessageSender.send(channel, file, "image/jpeg", onProgress = { percent -> ... }, onResult = { message, e -> ... })`;
   keep the returned pending message to show it with a progress bar, and `FileMessageSender.cancel(channel, pending)` stops it.
3. When `onResult` gets an error, keep the failed message and offer Retry: `FileMessageSender.resend(channel, failed, onProgress, onResult)`.
4. With a `MessageCollection`, the pending → sent/failed change also arrives in `onMessagesUpdated`
   (see `knowledge/curated/android/cross-cutting/pitfalls.md` "Messages (file send / resend)").

### Edit and delete messages (`MessageEditing.kt`)
1. In the message long-press menu, show Edit and Delete only when `MessageEditor.isMine(message)`.
2. Edit: `MessageEditor.edit(channel, userMessage, text) { updated, e -> ... }`, then replace the row with `updated`.
3. Delete: `MessageEditor.delete(channel, message) { e -> ... }`, then remove the row.
4. Without a `MessageCollection`, create `MessageChangeListener(channelUrl, onUpdated, onDeleted)`, call `start()` in
   `onCreate` and `stop()` in `onDestroy`, so other members' edits and deletes show up too.

### Unread counts (`UnreadCount.kt`)
1. After connect, keep one `UnreadCountTracker { total -> ... }` (for example in the Application or the main activity's
   ViewModel) and call `start()`; set the badge in the lambda. Call `stop()` on sign-out.
2. The Android docs say the live unread event is turned off by default, so also call `refresh()` in `onResume`.
3. Per row: `UnreadCountTracker.unreadCount(channel)`. When a conversation opens, call `tracker.markRead(channel)`.

### Typing indicator and read receipts (`TypingAndReadReceipts.kt`)
1. In the conversation screen create `ChannelActivityTracker(channelUrl, onTypingChanged, onReadReceiptsChanged)`;
   `start()` in `onCreate`, `stop()` in `onDestroy`.
2. In the input's `TextWatcher.onTextChanged` call `ChannelActivityTracker.onTextChanged(channel, text)`; after sending call `channel.endTyping()`.
3. Show "… is typing" from `onTypingChanged`. Call `ChannelActivityTracker.markRead(channel)` when the screen shows and when a new message arrives.
4. For your own messages, show a read mark when `ChannelActivityTracker.unreadMemberCount(channel, message) == 0`,
   and rebind visible rows on `onReadReceiptsChanged`.

## Variations (see knowledge/curated/android/products/chat.md, all cited)
- Authenticated: `SendbirdChat.connect(userId, authToken) { user, e -> }`.
- Channels: load/create a `GroupChannel` before `send(...)`.
- Prebuilt screens that already include all of the above: Sendbird UIKit (`templates/android/view/uikit`).
