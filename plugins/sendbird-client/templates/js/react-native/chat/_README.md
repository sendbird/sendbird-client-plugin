<!-- status: populated -->
# templates/js/react-native/chat

Chat init + connect on React Native (`@sendbird/chat`, platform-agnostic core), plus the most requested message features.
From sendbird.com/docs (chat v4 javascript getting-started, verified 2026-06-09) and the shipped `@sendbird/chat` type
declarations (feature files against 4.22.11 and 4.22.14).
**Type-checked** against the real package (`tools/templates/compile-check-js.sh`, `tsc --strict`, pinned and latest).

Sources: (source: knowledge/curated/js/products/chat.md) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

## Files
- `connect.ts` — `SendbirdChat.init` + `connectUser(userId, accessToken?)`.
- `PushRegistration.ts` — register and unregister the native FCM or APNs token.
- `FileMessageUpload.ts` — send a picked image or document (`{ uri, name, type }`), resend a failed file message. No upload progress on React Native (see the file header).
- `MessageEditing.ts` — edit and delete your own messages, and hear about other members' edits and deletes.
- `UnreadCount.ts` — `useTotalUnreadCount(sb)` hook for a tab badge, per-channel count, mark as read.
- `TypingAndReadReceipts.ts` — `useChannelActivity(sb, channel)` hook for "… is typing" and read marks.
- `KeyboardAvoidingScreen.tsx` — the root of a screen with a message input at the bottom, so the keyboard does not cover the input (React Native only, no Sendbird API).

## How to splice
1. `npm install @sendbird/chat`
2. Import `sb` / call `connectUser(...)` after login.
3. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; access/session tokens are secrets.

The feature files below assume a connected `sb` and a loaded group channel. Copy only the files the app needs.

### Conversation and thread screens (`KeyboardAvoidingScreen.tsx`)
1. Every screen you build with a message input at the bottom uses `<KeyboardAvoidingScreen style={styles.screen}>` as its root instead of `<View>`. Without it the keyboard covers the input and its Send button on iOS, and on Android 15 and later.
2. Pass `topOffset` only when something outside the screen draws above it (a navigator header: `useHeaderHeight()`); a header inside the screen counts as 0.

### Send an image or document (`FileMessageUpload.ts`)
1. Map the picker result to `{ uri, name, type }` (for an image picker asset: `uri`, `fileName`, `type`).
2. `sendFile(channel, file, { onPending, onSucceeded, onFailed })`; show the pending message with a spinner.
3. On `onFailed` keep the failed message and offer Retry: `resendFailedFile(channel, failed, callbacks, file)`.
4. Ask for photo library or camera permission first (see the `permissions-setup` skill).
5. A picker module with a privacy-manifest resource bundle (for example `react-native-image-picker`) declares iOS 9.0 for
   that bundle, which Xcode 27 refuses. The plugin's starters raise it in the Podfile's `post_install`; another project
   needs the same loop (knowledge/curated/js/hosts/react-native.md "Version compatibility checklist").

### Edit and delete messages (`MessageEditing.ts`)
1. In the long-press menu, show Edit and Delete only when `isMine(sb, message)`.
2. `await editMessage(channel, message, text)` returns the updated message; `await deleteMessage(channel, message)` removes it.
3. Without a `MessageCollection`: `useEffect(() => watchMessageChanges(sb, channel.url, { onUpdated, onDeleted }), [channel.url])`.

### Unread counts (`UnreadCount.ts`)
1. `const { total, refresh } = useTotalUnreadCount(isConnected ? sb : null)` in the tab navigator; pass `total` to `tabBarBadge`.
2. Call `refresh()` when `AppState` changes back to `'active'`. Per row: `channelUnreadCount(channel)`; when a
   conversation opens: `markChannelReadAndRefresh(channel, refresh)`.

### Typing indicator and read receipts (`TypingAndReadReceipts.ts`)
1. `const { typingNames, readReceiptsVersion } = useChannelActivity(sb, channel)` in the conversation screen (it marks the channel read on mount).
2. In the `TextInput`'s `onChangeText` call `onDraftChange(channel, text)`; after sending call `onDraftChange(channel, '')`.
3. Show "… is typing" from `typingNames`. For your own messages, show a read mark when
   `unreadMemberCount(channel, message) === 0`; `readReceiptsVersion` re-renders the list when someone reads.

## Variations (see knowledge/curated/js/products/chat.md, all cited)
- Open channels: add `OpenChannelModule` from `@sendbird/chat/openChannel`.
- Send: `channel.sendUserMessage({ message }).onSucceeded(...)`.
- Prebuilt UI: `@sendbird/uikit-react-native` (see uikit curated).
