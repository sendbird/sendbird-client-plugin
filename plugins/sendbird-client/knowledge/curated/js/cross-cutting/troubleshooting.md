<!-- last-verified-against: @sendbird/chat 4.22.13 / @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.9 / sendbird-calls 1.10.21 -->
<!-- verification-method: case-signal + sdk-surface -->
<!-- status: populated -->
# js — troubleshooting

> Symptom → cause → fix for JavaScript on the web (`@sendbird/chat` v4, `@sendbird/uikit-react` v3, `sendbird-calls`) and React Native (`@sendbird/uikit-react-native` v3, `@sendbird/calls-react-native`). Built from solved public cases (Sendbird community forum and GitHub), each fix re-checked against the pinned SDK packages (`@sendbird/chat` 4.22.13, `@sendbird/uikit-react` 3.19.1, `@sendbird/uikit-react-native` 3.12.9, `sendbird-calls` 1.10.21, `@sendbird/calls-react-native` 1.2.0). Case links are evidence of the symptom, not the spec; when a case and the shipped types disagree, the types win. Cases marked **community** were resolved by users, not Sendbird staff. Error codes follow knowledge/curated/js/cross-cutting/errors.md.

---

## Connect and auth

### "This session token is invalid", or a user who used to connect without a token now can't

- **Cause:** Once an access token or session token has been issued for a user, that user must always connect with a token, even if the application lets token-less users read and write.
- **Fix:** Pass the token as the second argument, `sb.connect(userId, authToken)`. When the token expires, hand the SDK a fresh one from your server through the `SessionHandler` (see knowledge/curated/js/products/auth.md). (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:4372 ; source: knowledge/curated/js/products/auth.md)
- **Cases:** https://community.sendbird.com/t/issue-connecting-without-access-token-despite-read-write-permission-enabled/11125, https://community.sendbird.com/t/channelllist-infinite-loading/8932

### React Native: after the app reloads, every channel call fails with "connection is required" (800101)

- **Cause:** The connection does not survive a JS reload or app restart. Calls made before `connect` resolves fail with `CONNECTION_REQUIRED` (800101).
- **Fix:** Store the user ID (and token, in secure storage) at login. On every app start, call `sb.connect(userId, authToken)` and wait for it before you fetch channels or messages. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:4372, 4866 ; source: knowledge/curated/js/cross-cutting/errors.md)
- **Cases:** https://community.sendbird.com/t/how-to-persist-user-in-my-app/8336

### React Native: channel handlers stop firing while the app is in the background or the screen is locked

- **Cause:** The JS thread does not run in the background, so the SDK cannot deliver events to handlers there.
- **Fix:** Call `sb.setBackgroundState()` when the app goes to the background and `sb.setForegroundState()` when it comes back (see knowledge/curated/js/hosts/react-native.md). Use `GroupChannelCollection` and `MessageCollection` for your screens so they catch up on missed changes after the app returns to the foreground. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:4398, 4403 ; source: knowledge/curated/js/hosts/react-native.md)
- **Cases:** https://community.sendbird.com/t/onchannelchanged-onmessagereceived-do-not-trigger-when-app-in-background-or-lockscreen/7471

---

## Build and setup

### Next.js: "Cannot use import statement outside a module" or "self is not defined" during server rendering

- **Cause:** The UIKit and Calls packages run only in the browser. When Next.js renders the page on the server, the import fails.
- **Fix — Web:** Render Sendbird components only on the client. Load the component that imports `@sendbird/uikit-react` with Next.js `dynamic(() => import(...), { ssr: false })`. For `sendbird-calls`, the "self is not defined" crash was fixed in 1.10.5, so use 1.10.5 or later (the pinned 1.10.21 includes the fix).
- **Cases:** https://community.sendbird.com/t/syntaxerror-cannot-use-import-statement-outside-a-module/5142, https://community.sendbird.com/t/sendbird-calls-v1-9-3-error-referenceerror-self-is-not-defined/6885

### Errors that come from two copies of a Sendbird package

- **Symptom — React Native:** After an upgrade, UIKit hooks report a missing BottomSheet or ActionMenu context.
- **Cause:** The app installed its own copy of a package that UIKit already depends on, at a different version. The bundle then holds two copies, and React contexts from one copy do not match the other.
- **Fix — React Native:** Do not add `@sendbird/uikit-react-native-foundation` or `@sendbird/uikit-chat-hooks` at a different version. `@sendbird/uikit-react-native` 3.12.9 pins both to exactly 3.12.9, so remove your own entry or match it exactly. (source: @sendbird/uikit-react-native 3.12.9 package.json `dependencies`)
- **Fix — Web:** `@sendbird/uikit-react` 3.19.1 lists `@sendbird/chat` `^4.22.12` under `dependencies`, so it brings its own Chat SDK. If your `package.json` also lists `@sendbird/chat`, keep that entry inside UIKit's range or remove it, then run `npm ls @sendbird/chat` (or `yarn why @sendbird/chat`) and make sure only one version is installed. (source: https://unpkg.com/@sendbird/uikit-react@3.19.1/package.json)
- **Cases:** https://community.sendbird.com/t/error-uikit-hooks-after-upgrading-to-react-native-0-72/8050

### React Native: `SendbirdUIKitContainer` throws "Cannot read property 'options' of undefined", or asks for media packages you don't use

- **Cause:** `platformServices` is a required prop of `SendbirdUIKitContainer`, and every service in it is required: `file`, `notification`, `clipboard`, `media`, `player`, and `recorder`. `player` and `recorder` were added for voice messages in UIKit 3.2.0, so containers written for older versions miss them. (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/containers/SendbirdUIKitContainer.d.ts:28-35)
- **Fix:** Create the two services with `createNativePlayerService` and `createNativeRecorderService` (React Native CLI), or with `createExpoPlayerService` and `createExpoRecorderService` (Expo), and pass them in `platformServices`. For a feature you don't use, you can pass your own object that implements `PlayerServiceInterface` or `RecorderServiceInterface` instead of installing the native module. (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/index.d.ts:67-68, 73-75 ; lib/typescript/src/platform/types.d.ts:101, 160 ; source: https://sendbird.com/docs/chat/uikit/v3/react-native/core-components/provider/platformserviceprovider ; source: knowledge/curated/js/products/uikit.md)
- **Cases:** https://community.sendbird.com/t/sendbirduikitcontainer-react-native-can-not-read-property-options-of-undefined/8682, https://community.sendbird.com/t/unnecessary-packages-are-needed-in-react-native-ui-kit/8876

### React Native Calls: the Android build fails the 16 KB page-size check

- **Cause:** Versions of `@sendbird/calls-react-native` older than 1.1.9 ship native libraries that are not aligned for 16 KB memory pages.
- **Fix:** Upgrade `@sendbird/calls-react-native` to 1.1.9 or later (the pinned 1.2.0 qualifies).
- **Cases:** https://community.sendbird.com/t/reactnative-android-16kb-page-size-issue/11213

---

## Channel list and channel creation

### A channel created through the Platform API (or after clearing its history) doesn't appear in the channel list

- **Cause:** A channel with no messages is an empty channel, and empty channels are excluded by default (`includeEmpty`, default `false`). Clearing a channel's history with `resetMyHistory()` also leaves it empty for that user. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:5761-5765)
- **Fix — Web:** Use `GroupChannelList` with `channelListQueryParams={{ includeEmpty: true }}` and render `GroupChannel` next to it. The all-in-one `App` component has no prop for list query params. (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannelList/context/GroupChannelListProvider.d.ts:15, 25 ; types/modules/App/types.d.ts:42-80)
- **Fix — React Native:** Pass `channelListQueryParams={{ includeEmpty: true }}` to `GroupChannelListFragment`. `collectionCreator` still works but is deprecated. (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/domain/groupChannelList/types.d.ts:21-26)
- **Cases:** https://community.sendbird.com/t/my-sendbird-ui-kit-is-not-showing-channels-that-are-created-by-api/6811, https://community.sendbird.com/t/channels-are-not-appearing-the-channellist-once-the-reset-the-history/8927, https://community.sendbird.com/t/how-to-includeempty-for-react-native-groupchannellistfragment/8384 — community

### Web UIKit: with a custom channel list query, the list keeps reloading, or selecting a channel always opens the first one

- **Cause:** By default the channel list selects the first channel whenever no channel is selected, and that fights with your own selection logic (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannelList/context/GroupChannelListProvider.tsx#L141-L146).
- **Fix — Web:** Set `disableAutoSelect` on the list (`GroupChannelList`, or the legacy `ChannelList` if you still use `queries`). Then drive selection yourself with `onChannelSelect` and `selectedChannelUrl`. (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannelList/context/GroupChannelListProvider.d.ts:17, 20, 22 ; types/modules/ChannelList/context/ChannelListProvider.d.ts:51, 54)
- **Cases:** https://community.sendbird.com/t/why-when-i-pass-on-props-queries-channellistquery-includeempty-true-app-is-stuck-and-make-endless-requests/6816, https://community.sendbird.com/t/how-to-use-queries-channellistquery-in-the-right-way/7167

### Starting a chat with the same person creates a new channel every time

- **Cause:** Channels are not distinct unless you ask for it, so each create call makes a new channel.
- **Fix:** Set `isDistinct: true` in the create params. The server then returns the existing channel with the same members. A public channel cannot be distinct, so leave `isPublic` unset. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:5525, 5535, 5542-5543)
- **Fix — Web UIKit:** Return the params from `onBeforeCreateChannel(users)` on `GroupChannelList`. (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannelList/context/GroupChannelListProvider.d.ts:28)
- **Fix — React Native UIKit:** Return the params from `onBeforeCreateChannel(params, users)` on the fragment made by `createGroupChannelCreateFragment`, and from `uikitOptions`' `userProfile.onBeforeCreateChannel` for the profile card's "message" button. (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/domain/groupChannelUserList/types.d.ts:11 ; lib/typescript/src/containers/SendbirdUIKitContainer.d.ts:71-73)
- **Cases:** https://community.sendbird.com/t/multiple-channels-with-same-user-being-created-from-new-channel-screen/7366, https://community.sendbird.com/t/sbchannellist/7684 — community

### 400108 "User must be a member" for a user who appears in the channel

- **Cause:** The user was invited but never joined. Their member state is `invited`, not `joined`, so member-only calls fail with `NON_AUTHORIZED` (400108). This also happens when a user has reached the 2,000 joined-channel limit, because new invitations then stay pending (see knowledge/curated/js/cross-cutting/pitfalls.md).
- **Fix:** Check `channel.myMemberState`. If it is `MemberState.INVITED`, call `channel.acceptInvitation()`. For a channel that requires an access code, pass it: both `acceptInvitation(accessCode?)` and `join(accessCode?)` take it as an optional argument. To have invitations accepted automatically, call `sb.setChannelInvitationPreference(true)`. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:1923, 2086, 2097, 2472-2477, 4564, 4839 ; source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/inviting-users-to-a-group-channel/accept-or-decline-an-invitation ; source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/retrieving-channels/retrieve-a-list-of-channels)
- **Cases:** https://community.sendbird.com/t/not-authorized-user-must-be-a-member-when-user-already-member-in-groupchannel/8523, https://community.sendbird.com/t/new-group-channels-created-for-users-that-exceeded-2000-group-channels-causing-issues/6206

---

## Messages

### Messages sent before a user joined are missing, or fetching or reacting to one fails with "chat history is disabled"

- **Cause:** By default, members see only messages sent after they joined. This is an application setting, not an SDK option.
- **Fix:** Turn on chat history for group channels in the dashboard's channel settings. The change applies only to users who join after it is turned on. Earlier joins are not backfilled.
- **Cases:** https://community.sendbird.com/t/error-calling-get-message-by-id-for-message-sent-before-user-joins-a-group-channel/9451, https://community.sendbird.com/t/getting-first-message-of-channel/9507, https://community.sendbird.com/t/chat-history-when-joining-private-group-channel/2237

### Messages look sent but are gone after leaving and reopening the channel

- **Cause:** The channel is ephemeral. The channel overview says messages sent in an ephemeral group channel are not saved in Sendbird's database, so they can't be loaded again.
- **Fix:** Leave `isEphemeral` unset or `false` in the create params of channels whose history you need, and check `channel.isEphemeral` on existing ones. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/overview-channel) (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:5557 — `GroupChannelCreateParams.isEphemeral` ; :189 — `BaseChannel.isEphemeral`)
- **Cases:** https://community.sendbird.com/t/message-appears-to-get-deleted-right-after-sending-it/1902 (an iOS app; the cause is the channel type, not the platform)

### Thread replies also show up in the main message list

- **Cause — Web:** When UIKit's reply type is anything other than `NONE`, `GroupChannel` loads its list with the Chat SDK's `ReplyType.ONLY_REPLY_TO_CHANNEL`, so replies that were also sent to the channel are listed. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/context/GroupChannelProvider.tsx#L181-L184)
- **Fix — Web:** Keep `replyType="THREAD"` for the thread UI and pass `messageListQueryParams={{ replyType: ReplyType.NONE }}` to `GroupChannel`. The provider spreads your `messageListQueryParams` last when it creates the message collection, so your `replyType` wins. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/context/GroupChannelProvider.tsx#L478-L486) (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannel/context/types.d.ts:65)
- **Fix — React Native:** Pass `messageListQueryParams={{ replyType: ReplyType.NONE }}` to the group channel fragment. The fragment builds the collection's `MessageFilter` from those params. (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/fragments/createGroupChannelFragment.tsx#L363-L377) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannel/types.ts#L58-L65)
- `ReplyType` comes from `@sendbird/chat/message`. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:2647, 4077-4081)
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/116 (the same symptom in UIKit for iOS)

### Filtering messages by custom type does nothing

- **Cause:** The parameter is named `customTypesFilter`. A `customTypes` key is not part of the message list params, so it is silently ignored. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:2629-2638, 2712-2727)
- **Fix — Web UIKit:** Pass `customTypesFilter` inside `messageListQueryParams` on `GroupChannel`, or inside `queries.messageListParams` on the legacy `Channel`. (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannel/context/GroupChannelProvider.d.ts:60 ; types/modules/Channel/context/ChannelProvider.d.ts:17, 39)
- **Cases:** https://community.sendbird.com/t/adding-customtypes-to-messagelistparams-in-channel-queries-does-nothing/9061

### v3-style calls fail in v4: "startTyping is not a function", "Invalid parameter" from `createChannel`, no `addUserIds`

- **Cause:** In v4, module methods live on the SDK instance's module (`sb.groupChannel`) and channel methods live on a channel instance. Static calls such as `GroupChannel.createChannel(...)` or `GroupChannel.startTyping()` don't exist. Params are plain objects, not builder classes.
- **Fix:** Create and fetch channels through `sb.groupChannel.createChannel(params)` and `sb.groupChannel.getChannel(url)`. Put members in `invitedUserIds: string[]`. Call `startTyping()` and `endTyping()` on the channel you got back. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:2138, 2142, 5527, 6226, 6303 ; source: knowledge/curated/js/products/chat.md)
- **Cases:** https://community.sendbird.com/t/is-there-a-way-to-send-typing-indicator-now-currently-chatsdk-supports-groupchannel-starttyping-and-groupchannel-endtyping-but-i-am-not-able-to-use-these-to-show-typing-indicator/8338, https://community.sendbird.com/t/createchannel-giving-sendbirdexception-invalid-parameter/5476, https://community.sendbird.com/t/chat-sdk-v4-create-group-channel/4912

### `await channel.sendUserMessage(...)` doesn't give back the sent message

- **Cause:** `sendUserMessage` and `sendFileMessage` return a `MessageRequestHandler`, not a Promise, because a send reports twice: once as pending, then as succeeded or failed.
- **Fix:** Chain `.onPending(...)`, `.onFailed(...)` and `.onSucceeded(...)` on the returned handler, and read the sent message in `onSucceeded`. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:472, 2875-2897 ; source: knowledge/curated/js/products/chat.md)
- **Cases:** https://community.sendbird.com/t/chat-sdk-v4-send-message-onsucceeded-handler-not-called/4921

### A file message shows up as a generic file

- **Cause:** The file type must be a full MIME type; a bare type such as `"image"` is not one.
- **Fix:** Send a full MIME type such as `image/jpeg` in `mimeType`. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:1790-1800)
- **Cases:** https://community.sendbird.com/t/onsendfilemessage-not-working-when-type-is-set-to-image/5819

### There's no upload progress for file messages

- **Cause:** `sendFileMessage` does not report progress. Early v4 releases had no progress API at all, which is what the case below describes.
- **Fix:** In 4.22.13, upload first with `channel.uploadFile({ file, progressHandler })`. The `progressHandler` receives `(requestId, progress, total)`. Then send the message with the returned `url` as `fileUrl`. (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:516, 1794, 1824-1838, 5173 ; source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/sending-a-message/track-file-upload-progress-using-a-handler)
- **Cases:** https://community.sendbird.com/t/getting-upload-progress/5127

---

## Push

### React Native on iOS: every push notification arrives twice

- **Cause:** Sendbird sends one push per registered APNs credential, so two certificates for the same bundle ID produce two notifications. The credential lives in the dashboard, so the cause is the same whether the app is native iOS or React Native.
- **Fix:** Keep one APNs credential per bundle ID in the dashboard. (source: knowledge/curated/ios/cross-cutting/troubleshooting.md — Every push notification arrives twice)
- **Cases:** https://community.sendbird.com/t/chat-push-notification-is-coming-twice-in-ios/1913, https://community.sendbird.com/t/duplicate-push-notifications/4696 (native iOS apps)

---

## React Native UIKit media

### Taking a photo or video from the chat input does nothing, but picking from the library works

- **Cause:** Camera capture also needs the microphone permission, and the app had declared only the camera and photo permissions.
- **Fix:** Add every permission on the UIKit native modules list, including the microphone (`Privacy - Microphone Usage Description` on iOS, and the matching Android manifest entry). (source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/native-modules)
- **Cases:** https://community.sendbird.com/t/group-channel-take-video-and-camera-photo/8209

---

## Calls

### React Native: incoming calls don't ring, or the notification disappears with no call screen

- **Cause:** `@sendbird/calls-react-native` receives incoming calls only through push, whether the app is in the foreground, in the background, or closed. A plain remote notification is not enough to show a call screen. iOS needs a VoIP push with CallKit, and Android needs an FCM message that your app turns into an incoming-call notification.
- **Fix — iOS:** After `SendbirdCalls.authenticate(...)` resolves, register the VoIP token with `SendbirdCalls.ios_registerVoIPPushToken(token)`. Don't call `ios_unregisterVoIPPushToken` from a cleanup that runs right afterwards (for example a `useEffect` cleanup). (source: @sendbird/calls-react-native 1.2.0 lib/typescript/libs/SendbirdCallsModule.d.ts:140, 199-213 ; source: knowledge/curated/js/products/calls.md)
- **Fix — Android:** Register the FCM token with `SendbirdCalls.registerPushToken(token)`, and pass incoming FCM data to `SendbirdCalls.android_handleFirebaseMessageData(data)`. (source: @sendbird/calls-react-native 1.2.0 lib/typescript/libs/SendbirdCallsModule.d.ts:166, 229 ; source: https://sendbird.com/docs/calls/sdk/v1/react-native/direct-call/receiving-a-call/receive-a-call-in-the-background)
- **Cases:** https://community.sendbird.com/t/issues-using-of-github-repo-rn-direct-video-call/7483, https://community.sendbird.com/t/topic/7833, https://community.sendbird.com/t/react-native-ios-voip-token/10289

### Web: no remote audio or video, or incoming calls are missed

- **Cause:** The browser has not been granted media access before the first call, or the Calls WebSocket is not open. The web SDK receives calls only while its WebSocket is connected, and there is no push-based incoming call on the web.
- **Fix — Web:** Call `SendBirdCall.useMedia({ audio: true, video: true })` before making or accepting the first call. Call `SendBirdCall.connectWebSocket()` after `authenticate`, and keep the page open while the user should be reachable. (source: sendbird-calls 1.10.21 SendBirdCall.min.d.ts:6, 8, 27 ; source: knowledge/curated/js/products/calls.md)
- **Cases:** https://community.sendbird.com/t/how-to-access-the-remote-media/6694, https://community.sendbird.com/t/sendbirdcalls-in-flutter-desktop/6985

---

## Related

- Errors: knowledge/curated/js/cross-cutting/errors.md
- Pitfalls: knowledge/curated/js/cross-cutting/pitfalls.md
- Auth: knowledge/curated/js/products/auth.md
- React Native host: knowledge/curated/js/hosts/react-native.md
