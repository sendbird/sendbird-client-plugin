<!-- status: populated -->
# templates/android/compose/chat

`ChatViewModel.kt` — a `ViewModel` exposing a `StateFlow<ChatUiState>` plus a `ChatStatus`
composable, wrapping the verified Chat SDK calls. The SDK calls are identical to the verified
View-host template (`templates/android/view/chat/InitConnect.kt`); only the ViewModel/Compose
wrapper is new.

The feature ViewModels below do the same for the most requested message features. Each wraps the calls of the
matching View-host file in `templates/android/view/chat/` (verified with `javap` on the `sendbird-chat` 4.36.4 and
4.36.5 AARs).

Sources: (source: knowledge/curated/android/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html)

## Files
- `ChatViewModel.kt` — connect, send, connection state (`ChatStatus`).
- `FileUploadViewModel.kt` — send an image or file with upload progress, cancel, retry a failed file message; `FileUploadStatus` composable (View-host counterpart: `FileMessageSender.kt`).
- `MessageActionsViewModel.kt` — edit and delete your own messages, and receive other members' edits and deletes as a `SharedFlow` (`MessageEditing.kt`).
- `UnreadCountViewModel.kt` — total unread count for a tab badge, live updates, per-channel count, mark as read; `UnreadCountBadge` composable (`UnreadCount.kt`).
- `ChannelActivityViewModel.kt` — typing indicator and read receipts for one conversation; `TypingIndicator` composable (`TypingAndReadReceipts.kt`).

## Splice steps
1. Add the Chat SDK: `settings.gradle` maven `https://repo.sendbird.com/public/maven`,
   `build.gradle` `implementation("com.sendbird.sdk:sendbird-chat:4.+")`. Enable Compose
   (`buildFeatures { compose = true }`) + the Kotlin Compose compiler plugin.
2. Keep `SendbirdChat.init(...)` in your `Application` class (see the View-host template).
3. Copy `ChatViewModel.kt` into your app, adjust the package.
4. Drive it from a composable:
   ```kotlin
   @Composable
   fun ChatScreen(vm: ChatViewModel = viewModel()) {
       LaunchedEffect(Unit) { vm.connectUser("USER_ID") }
       ChatStatus(vm)
   }
   ```
5. App ID from `BuildConfig`/secret (do not hard-code). Authenticated apps connect with a token:
   `SendbirdChat.connect(userId, authToken) { ... }`.

## Feature ViewModels
Copy only the files the app needs and adjust the package. The per-conversation ViewModels are scoped to the
conversation destination (`viewModel()` inside that `composable(...)` route), so they are cleared, and their handlers
removed, when the user leaves it.

### Send an image or file (`FileUploadViewModel.kt`)
1. Pick with `rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia())`, copy the `Uri` into a
   `File` in `cacheDir`, then `vm.send(channel, file, "image/jpeg")`.
2. Put `FileUploadStatus(vm, channel)` above the input: it shows a progress bar while uploading and a Retry button after
   a failure. A Cancel button calls `vm.cancel(channel)`.

### Edit and delete messages (`MessageActionsViewModel.kt`)
1. Call `vm.watch(channel.url)` once (skip it when the list already uses a `MessageCollection`).
2. In the message long-press menu, show Edit and Delete only when `vm.isMine(message)`; they call
   `vm.edit(channel, userMessage, text)` and `vm.delete(channel, message)`.
3. `LaunchedEffect(Unit) { vm.changes.collect { change -> ... } }` replaces (`Updated`) or removes (`Deleted`) rows.

### Unread counts (`UnreadCountViewModel.kt`)
1. Scope one `UnreadCountViewModel` to the activity (or the nav graph that holds the tabs) and call `vm.start()` after connect.
2. Put `UnreadCountBadge(vm)` in the tab's badge. The Android docs say the live unread event is turned off by default,
   so call `vm.refresh()` when the channel list resumes (for example in a `LifecycleResumeEffect`).
3. Per row: `vm.unreadCount(channel)`. When a conversation opens, call `vm.markRead(channel)`.

### Typing indicator and read receipts (`ChannelActivityViewModel.kt`)
1. `LaunchedEffect(channel.url) { vm.watch(channel) }` (it also marks the channel read).
2. In the text field's `onValueChange` call `vm.onTextChanged(channel, it)`; call `vm.sent(channel)` after sending.
3. Put `TypingIndicator(vm)` above the input. Call `vm.markRead(channel)` when a new message arrives on screen.
4. For your own messages, show a read mark when `vm.unreadMemberCount(channel, message) == 0`, and collect
   `vm.readReceiptsVersion` in the same composable so it recomposes when someone reads.

## Notes
- Message UI: Chat SDK is headless. For prebuilt Compose chat screens use the Compose-native UIKit
  (`com.sendbird.sdk:uikit-compose`, see `templates/android/compose/uikit`).
- `StateFlow` + `collectAsState()` keeps Compose recomposition in sync with SDK callbacks.

## Compile status
`tools/templates/compile-check-android.sh` compiles every file here (with the Compose compiler plugin and
Compose deps) together with the View templates, against both the pinned and the latest SDK set.
