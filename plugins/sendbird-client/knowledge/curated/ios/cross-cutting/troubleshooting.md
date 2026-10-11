<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 / sendbird-uikit-ios 3.36.2 / sendbird-calls-ios 1.12.3 -->
<!-- verification-method: case-signal + sdk-surface -->
<!-- status: populated -->
# ios — troubleshooting

> Symptom, cause, and fix for iOS problems that came up repeatedly in solved public cases (the Sendbird community forum and GitHub discussions under github.com/sendbird). Each fix was re-checked against the pinned SDK surface (SendbirdChatSDK 4.39.11, SendbirdUIKit 3.36.2, SendBirdCalls 1.12.3), and every SDK symbol below cites the `.swiftinterface` line or curated doc it was found in; a public source is added where it shows the same symbol. Behavior claims come from the linked case, where a Sendbird staff member gave the answer unless the case is marked **community** (resolved by the asker or another user). Cases are signal, not spec: when a case predates the pinned SDK, only the part that still holds is kept. Error codes follow knowledge/curated/ios/cross-cutting/errors.md.

## Connect and auth

### `connect` or Calls `authenticate` fails with 400302
- **Cause:** The application requires an access or session token for this user, and the app connected without one or with a stale one. Once a token has been issued for a user, that user must always connect with a token; tokens can be re-issued but not removed.
- **Fix:** Issue the token on your server through the Platform API and pass it to `SendbirdChat.connect(userId:authToken:completionHandler:)` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6321) or to `SendBirdCall.authenticate(with:completionHandler:)` with `AuthenticateParams(userId:accessToken:)` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:877, :180; also source: knowledge/curated/ios/products/calls.md). 400302 is `accessTokenNotValid` (source: knowledge/curated/ios/cross-cutting/errors.md). Token refresh flow: knowledge/curated/ios/products/auth.md.
- **Cases:** https://community.sendbird.com/t/access-token-is-invalid-for-voice-video-calls-during-sign-in/2726, https://community.sendbird.com/t/changing-access-token-permission/3282

### UIKit shows every message on the left, or UIKit features such as reactions are missing
- **Cause:** UIKit does not know who the current user is. This happens when the app connects through the Chat SDK directly and never sets the UIKit user, so UIKit cannot tell which messages are the user's own.
- **Fix:** Set `SBUGlobals.currentUser` to an `SBUUser(userId:nickname:profileURL:)` before presenting any UIKit screen, and connect with `SendbirdUI.connect(completionHandler:)` instead of the Chat SDK's connect (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:5798, :15355, :16533; also source: knowledge/curated/ios/products/uikit.md).
- **Cases:** https://community.sendbird.com/t/sendbird-uikit-position-chat-messages/2493 — community, https://community.sendbird.com/t/reaction-issues-with-sbuchannelviewcontroller/1802 — community

### The device keeps receiving push notifications after the user logs out
- **Cause:** Disconnecting does not remove the device's push token, so the server keeps sending pushes for the previous user.
- **Fix:** On logout, call `SendbirdChat.unregisterPushToken(_:completionHandler:)` first and `SendbirdChat.disconnect(completionHandler:)` in its completion (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6406, :6341; also source: knowledge/curated/ios/cross-cutting/push.md). The UIKit version and a build-checked snippet are in that push doc.
- **Cases:** https://community.sendbird.com/t/how-do-you-deauthenticate-a-user/1587

## Channels

### A channel created on the server or in the dashboard does not appear in the UIKit channel list
- **Cause:** The default UIKit channel list query leaves out channels that have no messages yet, so a channel created by your backend stays hidden until someone sends a message. A private channel created in the dashboard also has to include the user as a member.
- **Fix:** Build a query with `GroupChannel.createMyGroupChannelListQuery(paramsBuilder:)` and set `includeEmptyChannel = true` on its params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:2730, :3169; also source: knowledge/curated/ios/products/chat.md). Pass it to `SBUGroupChannelListViewController(channelListQuery:)`, or override `createViewModel(channelListQuery:)` in a subclass (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:6176, :6185; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/45).
- **Cases:** https://community.sendbird.com/t/channels-created-from-api-not-showing-in-the-app/8925, https://github.com/sendbird/sendbird-uikit-ios/discussions/45, https://community.sendbird.com/t/sendbird-uikit-not-showing-private-chat/354

### UIKit creates a new 1:1 channel every time with the same user
- **Cause:** Channels created from the UIKit create-channel screen are not distinct by default, so each creation makes a new channel instead of returning the existing one.
- **Fix:** Set `isDistinct = true` on the channel create params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:3247; also source: knowledge/curated/ios/products/chat.md). In UIKit, apply it to every channel UIKit creates through `SBUGlobalCustomParams.groupChannelParamsCreateBuilder` (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:5725; also source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.2/Sources/SBUGlobalCustomParams.swift).
- **Cases:** https://community.sendbird.com/t/sendbird-uikit-duplicate-channels/1012, https://community.sendbird.com/t/multiple-channels-with-same-user-being-created-from-new-channel-screen/7366

### A group channel disappears after every member leaves
- **Cause:** By default the server deletes a group channel when its member count reaches zero. Channels do not expire from inactivity.
- **Fix:** No client change keeps the channel. Ask Sendbird support to change the application setting so empty channels are kept.
- **Cases:** https://community.sendbird.com/t/group-channel-is-automatically-deleted-when-the-number-of-users-reaches-0/10161, https://community.sendbird.com/t/channel-with-0-member/8138, https://community.sendbird.com/t/all-channels-deleted/7299

### Creating a channel from the app fails with 400108
- **Cause:** The application is set to block channel creation from clients, so `GroupChannel.createChannel(params:completionHandler:)` is rejected (source: knowledge/curated/ios/products/chat.md). 400108 is `nonAuthorized` (source: knowledge/curated/ios/cross-cutting/errors.md).
- **Fix:** Create channels from your server with the Platform API, or ask Sendbird support to allow client-side creation for the application.
- **Cases:** https://community.sendbird.com/t/topic/5679, https://community.sendbird.com/t/is-it-possible-to-forbid-all-users-from-creating-a-channel/5047

## Messages and threads

### Messages look sent but are gone after leaving and reopening the channel
- **Cause:** The channel was created as ephemeral, and an ephemeral channel does not keep its messages.
- **Fix:** Create the channel with `isEphemeral` left at `false` on the channel create params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:3248). Existing ephemeral channels stay ephemeral, so create a new one.
- **Cases:** https://community.sendbird.com/t/message-appears-to-get-deleted-right-after-sending-it/1902

### Replying to a reply fails with an invalid parent message error
- **Cause:** Sendbird threads are one level deep, so a reply cannot be the parent of another reply.
- **Fix:** Always use the thread's root message as the parent. When the user replies to a reply, read that message's `BaseMessage.parentMessageId` and set it as `parentMessageId` on the create params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:1036, :1226; also source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/create-a-message-thread). A build-checked reply and list-replies example is in "Message threads" in knowledge/curated/ios/products/chat.md.
- **Cases:** https://community.sendbird.com/t/error-reply-message/4219

### Thread replies also show up in the main message list
- **Cause:** By default a reply is also shown in the channel, and the message list loads replies along with top-level messages.
- **Fix:** Set `SendbirdUI.config.groupChannel.channel.replyType = .thread` after UIKit initializes (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:16525, :3661, :3504, :3577, :13455; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/116). In an `SBUGroupChannelViewController` subclass, override `createViewModel(channel:channelURL:messageListParams:startingPoint:showIndicator:)` to pass a `MessageListParams` whose `replyType` is `.onlyReplyToChannel` (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:7379; SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:4193, :4559). Register the subclass in `SBUViewControllerSet.GroupChannelViewController` (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:16183). Set `isReplyToChannel = false` on outgoing params through `SBUGlobalCustomParams.userMessageParamsSendBuilder` and `SBUGlobalCustomParams.fileMessageParamsSendBuilder` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:1227; SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:5729, :5731; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/116).
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/116

### Changing `messageListParams` after the channel screen is created has no effect
- **Cause:** `SBUGroupChannelViewController` reads the params only when it creates its view model, at initialization.
- **Fix:** Pass the params at init with `SBUGroupChannelViewController(channelURL:startingPoint:messageListParams:)` (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:7363; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/63). To change them later, set `viewModel.customizedMessageListParams` and call `loadInitialMessages(startingPoint:showIndicator:initialMessages:)`, which reloads the list with the new params (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:7339, :1961, :1976).
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/63

## UIKit layout and appearance

### The message input sits in the wrong place when the keyboard opens
- **Cause:** With a custom tab bar (not the one from `UITabBarController`), UIKit can compute the tab bar height wrongly and leave extra space above the keyboard. A UIKit screen wrapped in SwiftUI can also jump to the top because UIKit already accounts for safe area insets.
- **Fix:** For a custom tab bar, override `getAdjustedKeyboardHeight(with:)` and `getTabBarHeight()` in your channel view controller subclass to return the correct values (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:1573, :1574). For a SwiftUI wrapper, apply `.ignoresSafeArea()` (at least the bottom edge) to the wrapped view.
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/113, https://community.sendbird.com/t/uikit-textfield-goes-up-to-the-top-when-user-taps-the-textfield/2193

### Sendbird SwiftUI screens show two navigation bars
- **Cause:** The Sendbird SwiftUI views host UIKit view controllers that bring their own navigation bar, so a SwiftUI navigation bar on the host adds a second one.
- **Fix:** Hide the SwiftUI navigation bar on the view that hosts the Sendbird screen.
- **Cases:** https://github.com/sendbird/sendbird-swiftui-ios/discussions/7, https://community.sendbird.com/t/swiftui-sdk-integration/10082

### UIKit chrome does not follow the system light or dark appearance on iOS 26
- **Cause:** Liquid Glass chrome follows `SBUTheme.colorScheme` by default, so it keeps the old scheme when the system appearance changes unless the app updates the theme.
- **Fix:** With static theme colors, keep `SBUTheme.liquidGlassAppearance` at `.theme`, call `SBUTheme.set(colorScheme:)` and re-apply your colors on every appearance change, then call `updateStyles()` on the visible screen. With trait-based dynamic `UIColor`s, set `SBUTheme.liquidGlassAppearance` to `.system` once at launch. Setting `SendbirdUI.config.common.isLiquidGlassEnabled` to `false` turns Liquid Glass off (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:14280, :14183, :14184, :14194, :2542, :16525, :3660, :3493; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/193). The appearance and Liquid Glass switches are iOS 26.0+ APIs, and the case targets UIKit 3.36.0 or later.
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/193

## Push

### Every push notification arrives twice
- **Cause:** Sendbird sends one push per registered APNs credential, so two certificates for the same bundle ID produce two notifications. An app that also posts its own local notification from a background handler shows a second copy as well.
- **Fix:** Keep one APNs credential per bundle ID in the dashboard. Do not post a local notification for a push the system already displays.
- **Cases:** https://community.sendbird.com/t/chat-push-notification-is-coming-twice-in-ios/1913, https://community.sendbird.com/t/duplicate-push-notifications/4696, https://community.sendbird.com/t/push-notifications-are-received-twice-by-all-ios-users/8158 — community

### Push notifications never arrive, for Chat messages or Calls
- **Cause:** The APNs credential in the dashboard does not match the app. The usual reasons are a certificate for another bundle ID, a .p8 key set to Production while the build uses a development token (APNs answers `BadDeviceToken`), or push not being turned on for the application at all.
- **Fix:** Upload a credential for the app's bundle ID and pick the environment that matches the build (Development for debug builds, Production for release builds). Then sign out and back in so the app registers its token again, as the Calls case does. Setup steps: knowledge/curated/ios/cross-cutting/push.md.
- **Cases:** https://community.sendbird.com/t/not-receiving-push-notifications-in-ios-after-registering-tokem/4593, https://community.sendbird.com/t/apns-errors-when-using-p8-token/7967, https://github.com/sendbird/sendbird-calls-ios/discussions/27

### Only the most recently used device gets push notifications
- **Cause:** The token was registered with `unique: true`, which removes the user's other tokens.
- **Fix:** Register with `unique: false` in `SendbirdChat.registerDevicePushToken(_:unique:completionHandler:)` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6399; also source: knowledge/curated/ios/cross-cutting/push.md). For Calls, use `unique: false` in `SendBirdCall.registerVoIPPush(token:unique:completionHandler:)` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:884; also source: knowledge/curated/ios/products/calls.md). The Chat case also says to turn on multi-device push in the dashboard.
- **Cases:** https://community.sendbird.com/t/multi-device-ios-push-notification-support/3024, https://community.sendbird.com/t/notifications-for-multiple-devices/1536

## Calls

### The app is terminated when a VoIP push arrives in the background
- **Cause:** On iOS 13 and later, the system terminates an app that receives a VoIP push without reporting an incoming call to CallKit.
- **Fix:** Forward the PushKit payload to `SendBirdCall.pushRegistry(_:didReceiveIncomingPushWith:for:completionHandler:)` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:883; also source: https://github.com/sendbird/sendbird-calls-ios). In `SendBirdCallDelegate.didStartRinging(_:)`, report the call with CallKit's `reportNewIncomingCall` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:650; also source: knowledge/curated/ios/products/calls.md). The public Calls QuickStart sample shows this flow.
- **Cases:** https://community.sendbird.com/t/app-gets-terminated-when-voip-push-is-received-when-app-in-background/701

## Related

- Error codes: knowledge/curated/ios/cross-cutting/errors.md
- Push setup: knowledge/curated/ios/cross-cutting/push.md
- Common mistakes: knowledge/curated/ios/cross-cutting/pitfalls.md
