<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 / sendbird-uikit-android 3.26.3 / sendbird-calls-android 1.12.5 -->
<!-- verification-method: case-signal + sdk-surface -->
<!-- status: populated -->
# android — troubleshooting

> Symptom → cause → fix entries built from solved public cases (Sendbird community forum and GitHub discussions). Each fix was re-checked against the pinned SDK surface (`javap` of sendbird-chat 4.36.5, uikit 3.26.3, sendbird-calls 1.12.5 and sendbird-common 1.0.7) or against the published POM and CHANGELOG. Behavior that only a case states is attributed to that case. Answers written for Chat v3 or UIKit v2 were rewritten for the current API or dropped. Case links marked **community** were resolved by the poster or another user, not by Sendbird staff. Verified 2026-10-08.

## Build and install

### Gradle can't resolve `com.sendbird.sdk:*` artifacts
- **Cause:** The Sendbird Maven repository is missing from the place Gradle actually reads repositories. Projects created with Gradle 7+ resolve dependencies from `dependencyResolutionManagement` in `settings.gradle(.kts)`, so a repository added only to the root `build.gradle` is ignored.
- **Fix:** Declare `maven { setUrl("https://repo.sendbird.com/public/maven") }` inside `dependencyResolutionManagement { repositories { ... } }` in `settings.gradle(.kts)`, then sync. Opening that URL in a browser returns 404; that is expected and does not mean the repository is down. (source: knowledge/curated/android/setup.md — Packaging) (staff answer in the first case below)
- **Cases:** https://community.sendbird.com/t/cant-install-non-jcenter-sdk-versions/4670, https://community.sendbird.com/t/cant-use-https-repo-sendbird-com-public-maven/2480 — community

### App crashes on Android 15 devices with 16 KB memory pages, or the APK ships unexpected Conscrypt `.so` files
- **Cause:** Chat SDK versions before 4.25.0 pulled in `org.conscrypt:conscrypt-android` (2.2.1 per the staff answer) for TLS 1.3. Its native libraries are not built for 16 KB page sizes, and they add native code to every ABI split.
- **Fix:** Upgrade to Chat SDK 4.25.0 or later. Starting with 4.25.0 the SDK no longer includes Conscrypt, and the 4.36.5 POM depends only on `sendbird-common`, `sendbird-auth`, `kotlin-stdlib` and `androidx.annotation`. Run `./gradlew :app:dependencies` to confirm nothing else still brings in an old Conscrypt. If you use UIKit, declare the newer Chat SDK explicitly (see setup.md). Add `conscrypt-android` back yourself only if you need TLS 1.3 on Android 9 or lower, and pick a release whose native libraries support 16 KB pages (the staff workaround forced 2.5.3). Without Conscrypt the SDK logs `Couldn't locate conscrypt dependency from your build.gradle`; the log itself says this is safe to ignore. (source: https://github.com/sendbird/sendbird-chat-sdk-android/blob/main/CHANGELOG.md — v4.25.0) (source: https://repo.sendbird.com/public/maven/com/sendbird/sdk/sendbird-chat/4.36.5/sendbird-chat-4.36.5.pom) (source: sendbird-chat 4.36.5 raw.txt:12503) (source: knowledge/curated/android/setup.md — Getting a newer Chat SDK under UIKit)
- **Cases:** https://github.com/sendbird/sendbird-chat-sdk-android/discussions/65, https://community.sendbird.com/t/add-support-for-android-15-16kb-page-size-plus-workaround/10539, https://community.sendbird.com/t/native-libraries-in-build-after-sendbird-integration/3026

### Opening a sent file or video fails with 800220 "Failed to find configured root", or UIKit shows "Couldn't open file."
- **Cause:** The app's own `FileProvider` collides with the one UIKit declares, or the app's provider paths XML does not cover the directory of the file. UIKit 3.26.3 merges its own provider into your manifest: class `com.sendbird.uikit.model.SendbirdUIKitFileProvider` (a subclass of `androidx.core.content.FileProvider`), authority `${applicationId}.sendbird.uikit.provider`, paths `@xml/sb_file_paths`. The error code is `SendbirdError.ERR_REQUEST_FAILED` (800220), and "Couldn't open file." is UIKit's `sb_text_error_open_file` string.
- **Fix:** Give your own provider a different authority, and keep your own paths XML that includes every directory you share. Do not reuse UIKit's authority, and do not replace UIKit's `<provider>` entry with `tools:replace`. (source: uikit 3.26.3 javap.txt:4644, plus pkg.aar AndroidManifest.xml and res/values/values.xml) (source: sendbird-common 1.0.7 javap.txt:77, value 800220 via `javap -constants`)
- **Cases:** https://community.sendbird.com/t/sendbirdexception-code-800220-message-failed-to-find-configured-root-that-contains/2822 — community, https://community.sendbird.com/t/getting-a-couldnt-open-file-toast-error-when-i-click-on-a-video/6461 — community, https://community.sendbird.com/t/sendbird-uikit-using-androidx-core-content-fileprovider-directly/2687

### UIKit shows only "Couldn't retrieve channel.", or creating a channel fails in some builds
- **Cause:** UIKit was never initialized, or the user was not connected yet. A typical case is an `Application` subclass that calls `SendbirdUIKit.init(adapter, context)` but is not registered with `android:name` in `AndroidManifest.xml`, so its `onCreate` never runs. Another is app code that calls Chat APIs, such as channel creation, before the connection completes.
- **Fix:** Call `SendbirdUIKit.init(...)` in `Application.onCreate` and register that class in the manifest. In your own screens, create channels only from the success callback of `SendbirdUIKit.connect(...)` or `SendbirdChat.connect(...)`; calling earlier fails with `ERR_CONNECTION_REQUIRED` (800101). (source: knowledge/curated/android/setup.md — Init) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/essentials/authentication) (source: uikit 3.26.3 javap.txt:5948, javap.txt:5966, res/values/values.xml `sb_text_error_get_channel`) (source: knowledge/curated/android/cross-cutting/errors.md)
- **Cases:** https://community.sendbird.com/t/uikit-2-2-4-couldnt-retrieve-channel-toast/4650, https://community.sendbird.com/t/please-help-me-on-this/2382

## Connection and auth

### `connect` fails with 400302, or a user who used to connect without a token is now rejected
- **Cause:** Either the session or access token expired or was revoked (`SendbirdError.ERR_INVALID_TOKEN`, 400302), or the user now has a token issued. According to Sendbird staff, once a token exists for a user, that user can no longer connect without one, even if the application allows token-less connections.
- **Fix:** Fetch a current token from your server before every `SendbirdChat.connect(userId, token, handler)`, and do not cache tokens indefinitely on the device. Call `SendbirdChat.setSessionHandler(...)` before `connect`, and answer `SessionHandler.onSessionTokenRequired(requester)` with a fresh token from your server. (source: knowledge/curated/android/products/auth.md — Session token expiry) (source: sendbird-chat 4.36.5 javap.txt:254, javap.txt:273, javap.txt:2957) (source: sendbird-common 1.0.7 javap.txt:53)
- **Cases:** https://community.sendbird.com/t/400302-invalidaccesstoken/3003, https://community.sendbird.com/t/sdk-is-throwing-the-exception/4388, https://community.sendbird.com/t/how-to-login-sdk-without-token-after-using-token/10025

### `GroupChannel.getChannel(url)` fails with 400201, or a channel suddenly disappears
- **Cause:** 400201 (`SendbirdError.ERR_NOT_FOUND_IN_DATABASE`) means no channel matches that URL: the URL is wrong or the channel was deleted. By default, a group channel is deleted automatically when its last member leaves or is removed, so URLs your app stored for such channels stop resolving.
- **Fix:** Treat 400201 from `getChannel` as "channel gone": drop the stored URL and refresh your list instead of retrying. If your product needs empty channels to survive, ask Sendbird support to change that application setting; staff answers say it can't be changed from the SDK. Sendbird does not record client exceptions for you, so log them yourself. (source: https://sendbird.com/docs/chat/sdk/v4/android/channel/retrieving-channels/retrieve-a-channel-by-url) (source: sendbird-chat 4.36.5 javap.txt:1208) (source: sendbird-common 1.0.7 javap.txt:42, value 400201 via `javap -constants`) (staff answers in the cases below)
- **Cases:** https://community.sendbird.com/t/getting-channel-not-found-exception-error-code-400201/3614, https://community.sendbird.com/t/group-channel-is-automatically-deleted-when-the-number-of-users-reaches-0/10161, https://community.sendbird.com/t/all-channels-deleted/7299

## Messages and channels

### `getMessagesByTimestamp` returns messages you already have (duplicates)
- **Cause:** `getMessagesByTimestamp(ts, params, handler)` on a channel returns `previousResultSize` messages before the timestamp and `nextResultSize` messages after it. Code migrated from an older "previous only" API often sets both sizes, so each page also returns messages newer than the timestamp, which are already on screen.
- **Fix:** When paging backwards, set `nextResultSize = 0` on the `MessageListParams` and set only `previousResultSize`. (source: https://sendbird.com/docs/chat/sdk/v4/android/message/retrieving-messages/retrieve-a-list-of-messages) (source: sendbird-chat 4.36.5 javap.txt:783, javap.txt:9695, javap.txt:10398)
- **Cases:** https://community.sendbird.com/t/how-to-migrate-to-getmessagesbytimestamp-from-getpreviousmessagesbytimestamp-on-android/6356

### `getUnreadMemberCount` is always 0 and `getReadMembers` is always empty
- **Cause:** Both methods return 0 or an empty list for an `AdminMessage` and in a Supergroup channel (`GroupChannel.isSuper` is true). They also return nothing while no user is connected.
- **Fix:** Check `message is AdminMessage` and `channel.isSuper` before showing read receipts. Supergroups do not support per-message read receipts, so hide the receipt UI there. (source: https://sendbird.com/docs/chat/sdk/v4/android/channel/overview-channel) (source: sendbird-chat 4.36.5 javap.txt:1047, javap.txt:1142, javap.txt:1145, plus `javap -c` of `getUnreadMemberCount` and `getReadMembers`) (source: knowledge/curated/android/products/chat.md — Read receipts for a message)
- **Cases:** https://community.sendbird.com/t/in-android-groupchannel-unreadmemberscount-always-0/3049

### A channel created elsewhere (server, another client) doesn't appear in the UIKit channel list
- **Cause:** UIKit's channel list builds its query from a default `GroupChannelListQueryParams`, whose `includeEmpty` is `false`. A channel with no messages stays hidden until someone sends the first message.
- **Fix:** Pass your own query: `ChannelListFragment.Builder.setGroupChannelListQuery(GroupChannel.createMyGroupChannelListQuery(GroupChannelListQueryParams().apply { includeEmpty = true }))`. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/channel-list-customization/filter-channel-list) (source: uikit 3.26.3 javap.txt:8629, plus `javap -c` of `ChannelListViewModel.createGroupChannelListQuery`) (source: sendbird-chat 4.36.5 javap.txt:1203, javap.txt:10066, javap.txt:10143; default `includeEmpty = false` via `javap -c` of the constructor)
- **Cases:** https://community.sendbird.com/t/sendbird-uikit-not-showing-private-chat/354

### UIKit creates a new 1:1 channel every time with the same user
- **Cause:** UIKit's create-channel screen sets `GroupChannelCreateParams.isDistinct` only when you ask for it. Otherwise the field stays unset and the server creates a new, non-distinct channel each time.
- **Fix:** Build the screen with `CreateChannelFragment.Builder.setIsDistinct(true)`. To apply it app-wide, register `SendbirdUIKit.setCustomParamsHandler(...)` and set `params.isDistinct = true` in `onBeforeCreateGroupChannel(params)`. With distinct on, creating a channel with the same members returns the existing one. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java) (source: uikit 3.26.3 javap.txt:5973, javap.txt:8738, javap.txt:9522, plus `javap -c` of `CreateChannelFragment`) (source: sendbird-chat 4.36.5 javap.txt:10030)
- **Cases:** https://community.sendbird.com/t/multiple-channels-with-same-user-being-created-from-new-channel-screen/7366

### Thread replies show up in the main UIKit message list
- **Cause:** When the UIKit reply type (`com.sendbird.uikit.consts.ReplyType`) is `QUOTE_REPLY` or `THREAD`, `ChannelViewModel.createMessageListParams()` loads the list with the Chat `com.sendbird.android.message.ReplyType.ONLY_REPLY_TO_CHANNEL`, so replies are included in the channel list.
- **Fix:** Keep the UIKit reply type as `THREAD` so the thread UI still works, and load the main list with the Chat `ReplyType.NONE`. Either pass your own `MessageListParams` (with `replyType = ReplyType.NONE`) through `ChannelFragment.Builder.setMessageListParams(...)`, which UIKit uses as given apart from forcing `reverse`, or override `createMessageListParams()` in a custom `ChannelViewModel`, as the staff answer does. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/filter-message-list) (source: uikit 3.26.3 javap.txt:218, javap.txt:8551, javap.txt:11347, plus `javap -c` of `ChannelViewModel`) (source: sendbird-chat 4.36.5 javap.txt:9271, javap.txt:10401)
- **Cases:** https://github.com/sendbird/sendbird-uikit-android/discussions/38

### After targeting SDK 35, UIKit screens draw under the status bar and navigation bar
- **Cause:** Android 15 enforces edge-to-edge for apps that target API 35, and older UIKit releases did not apply the window insets.
- **Fix:** Update UIKit to 3.23.0 or later. That release fixed edge-to-edge handling and added `SendbirdUIKit.setEdgeToEdgeConfig(EdgeToEdgeConfig)` to style the status bar in edge-to-edge mode. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/CHANGELOG.md — v3.23.0) (source: uikit 3.26.3 javap.txt:4384, javap.txt:5974)
- **Cases:** https://community.sendbird.com/t/improve-support-for-edge-to-edge-layout/10714 — community

## Push notifications

### No chat push arrives when the app is killed
- **Cause:** FCM wakes the app process without starting any Activity. If `SendbirdChat.init` and `SendbirdPushHelper.registerHandler(...)` run in a splash or main Activity, they never run for that push, so nothing handles it.
- **Fix:** Call `SendbirdChat.init(...)` and `SendbirdPushHelper.registerHandler(yourSendbirdPushHandler)` in `Application.onCreate`, and register the `Application` class in the manifest. (source: knowledge/curated/android/cross-cutting/push.md — Register the handler) (source: sendbird-chat 4.36.5 javap.txt:244, javap.txt:11609)
- **Cases:** https://community.sendbird.com/t/push-notifications-android-in-kill-state/3814, https://community.sendbird.com/t/chat-push-notification/3687

### No device token is registered, or Sendbird pushes stop after adding another FCM library
- **Cause:** The Chat SDK already declares `com.sendbird.android.push.SendbirdFirebaseMessagingService` (and an HMS service) in its manifest. An app-declared `FirebaseMessagingService` that handles the same `MESSAGING_EVENT` competes with it, so token updates and messages may never reach Sendbird. `SendbirdPushHandler` is not a `Service`; it is a handler that the SDK's service calls.
- **Fix:** Remove your own FCM (or HMS) messaging service from the manifest, subclass `SendbirdPushHandler`, and register it with `SendbirdPushHelper.registerHandler(...)`. According to Sendbird staff, FCM messages from your other backends are also passed to that handler's `onMessageReceived`, so handle them there. If you register tokens manually instead, call `SendbirdChat.registerPushToken(...)` after `connect` succeeds. (source: knowledge/curated/android/cross-cutting/push.md) (source: sendbird-chat 4.36.5 pkg.aar AndroidManifest.xml, javap.txt:302, javap.txt:11543, javap.txt:11580, javap.txt:11609)
- **Cases:** https://community.sendbird.com/t/uikit-android-push-notifications-no-device-token/3650, https://community.sendbird.com/t/fcm-hms-pushes-plus-sendbird-pushes/3807

### Push arrives in the background but not while the app is in the foreground
- **Cause:** By default Sendbird pushes only to devices that are not connected, and `SendbirdPushHandler.alwaysReceiveMessage()` returns `false`. While the app is in the foreground it is connected, so new messages arrive through channel event handlers instead.
- **Fix:** Show in-app alerts from your channel handler. If you really need a system push while online, enable the "Send to devices both offline and online" option that the staff answer mentions, and override `alwaysReceiveMessage()` to return `true`. (source: knowledge/curated/android/cross-cutting/push.md — Handler-based vs manual token registration) (source: sendbird-chat 4.36.5 javap.txt:11477)
- **Cases:** https://community.sendbird.com/t/fcm-push-notification-is-not-working-when-the-app-in-foreground/3969

### Push delivery or the dashboard test push fails with `MismatchSenderId` or `NotRegistered`
- **Cause:** These are FCM errors. `MismatchSenderId` means the FCM credentials uploaded to Sendbird and the `google-services.json` that issued the device token belong to different Firebase projects. `NotRegistered` means the stored token is stale, for example from an older build, a reinstall, or a build that points at another Firebase project.
- **Fix:** Upload credentials from the same Firebase project as the app's `google-services.json`, and check every build flavor. Then reinstall or refresh so a new token is registered: the `SendbirdPushHandler` path re-registers on `onNewToken`, and the manual path calls `SendbirdChat.registerPushToken(...)` after `connect`. (source: knowledge/curated/android/cross-cutting/push.md) (source: https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/managing-push-notifications/push-notification-tester) (source: sendbird-chat 4.36.5 javap.txt:302, javap.txt:11580)
- **Cases:** https://community.sendbird.com/t/issue-in-receiving-calls-notifications/565, https://community.sendbird.com/t/fcm-mismatchsenderid/7978, https://community.sendbird.com/t/urgent-fcm-push-alerts-not-being-sent/4020

## Calls

### `onRinging` never fires for incoming calls until the device has dialed once
- **Cause:** An incoming call reaches a device without a live Calls connection through FCM. If no push token is registered with Calls, the FCM message isn't passed to the SDK, or the user isn't authenticated after the app restarts, no ringing event is raised. Chat's `onMessageReceived` is not triggered for calls.
- **Fix:** On every app start, call `SendBirdCall.init(context, appId)`, `SendBirdCall.authenticate(params, handler)` and `SendBirdCall.addListener(id, listener)`. After authentication, register the FCM token with `SendBirdCall.registerPushToken(token, unique, handler)`. In your FCM `onMessageReceived`, pass the message data to `SendBirdCall.handleFirebaseMessageData(...)`, which returns `true` for Calls pushes. Upload the app's FCM credentials in the dashboard. (source: knowledge/curated/android/products/calls.md) (source: https://sendbird.com/docs/calls/sdk/v1/android/features/push-notifications) (source: sendbird-calls 1.12.5 javap.txt:766, javap.txt:767, javap.txt:772, javap.txt:777, javap.txt:784, javap.txt:1008)
- **Cases:** https://community.sendbird.com/t/onringing-is-not-invokded/1947 — community, https://community.sendbird.com/t/incoming-call-alert-not-working-in-android/3760

### Microphone or camera doesn't work during a call
- **Cause:** The Calls AAR declares `RECORD_AUDIO`, `CAMERA` and `BLUETOOTH_CONNECT` in its manifest, but those are runtime permissions. Declaring them does not grant them, and if they are granted only after media starts (for example after entering a group call room), audio and video may stay off.
- **Fix:** Request microphone and camera permissions at runtime, plus `BLUETOOTH_CONNECT` on Android 12 and later, before you dial, accept, or enter a room. (source: sendbird-calls 1.12.5 pkg.aar AndroidManifest.xml)
- **Cases:** https://community.sendbird.com/t/microphone-not-working/2346 — community, https://community.sendbird.com/t/quickstart-call-github-sample-incoming-video-is-not-showing-up/6892 — community, https://community.sendbird.com/t/audio-video-not-working-after-permission-granted/2698

## Related
- Errors: knowledge/curated/android/cross-cutting/errors.md
- Pitfalls: knowledge/curated/android/cross-cutting/pitfalls.md
- Push: knowledge/curated/android/cross-cutting/push.md
- Auth: knowledge/curated/android/products/auth.md
