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
- **Fix:** Set `SBUGlobals.currentUser` to an `SBUUser(userId:nickname:profileURL:)` before presenting any UIKit screen, and connect with `SendbirdUI.connect(completionHandler:)` instead of the Chat SDK's connect (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:5798, :15355, :16533; also source: knowledge/curated/ios/products/uikit.md). In the UIKit source, a message goes on the right only when its sender's user ID equals `SBUGlobals.currentUser`'s, and the emoji list that reactions need is loaded inside `SendbirdUI.connect` (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/MessageCellParams/SBUUserMessageCellParams.swift#L55-L59; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L251-L254).
- **Cases:** https://community.sendbird.com/t/sendbird-uikit-position-chat-messages/2493 — community, https://community.sendbird.com/t/reaction-issues-with-sbuchannelviewcontroller/1802 — community

### The device keeps receiving push notifications after the user logs out
- **Cause:** Disconnecting does not remove the device's push token, so the server keeps sending pushes for the previous user.
- **Fix:** On logout, call `SendbirdChat.unregisterPushToken(_:completionHandler:)` first and `SendbirdChat.disconnect(completionHandler:)` in its completion (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6406, :6341; also source: knowledge/curated/ios/cross-cutting/push.md). The UIKit version and a build-checked snippet are in that push doc.
- **Cases:** https://community.sendbird.com/t/how-do-you-deauthenticate-a-user/1587

## Channels

### A channel created on the server or in the dashboard does not appear in the UIKit channel list
- **Cause:** The default UIKit channel list query leaves out channels that have no messages yet, so a channel created by your backend stays hidden until someone sends a message.
- **Fix:** Build a query with `GroupChannel.createMyGroupChannelListQuery(paramsBuilder:)` and set `includeEmptyChannel = true` on its params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:2730, :3169; also source: knowledge/curated/ios/products/chat.md). Pass it to `SBUGroupChannelListViewController(channelListQuery:)`, or override `createViewModel(channelListQuery:)` in a subclass (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:6176, :6185; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/45).
- **Cases:** https://community.sendbird.com/t/channels-created-from-api-not-showing-in-the-app/8925, https://github.com/sendbird/sendbird-uikit-ios/discussions/45, https://community.sendbird.com/t/sendbird-uikit-not-showing-private-chat/354

### UIKit creates a new 1:1 channel every time with the same user
- **Cause:** Channels created from the UIKit create-channel screen are not distinct by default, so each creation makes a new channel instead of returning the existing one. UIKit sets `isDistinct = false` before it applies your create builder (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/SelectUser/CreateChannel/SBUCreateChannelViewModel.swift#L222-L239).
- **Fix:** Set `isDistinct = true` on the channel create params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:3247; also source: knowledge/curated/ios/products/chat.md). In UIKit, apply it to every channel UIKit creates through `SBUGlobalCustomParams.groupChannelParamsCreateBuilder` (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:5725; also source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.2/Sources/SBUGlobalCustomParams.swift).
- **Cases:** https://community.sendbird.com/t/sendbird-uikit-duplicate-channels/1012, https://community.sendbird.com/t/multiple-channels-with-same-user-being-created-from-new-channel-screen/7366

### A group channel disappears after every member leaves
- **Cause:** By default the server deletes a group channel when its member count reaches zero. Channels do not expire from inactivity.
- **Fix:** No client change keeps the channel. Ask Sendbird support to change the application setting so empty channels are kept.
- **Cases:** https://community.sendbird.com/t/group-channel-is-automatically-deleted-when-the-number-of-users-reaches-0/10161, https://community.sendbird.com/t/channel-with-0-member/8138, https://community.sendbird.com/t/all-channels-deleted/7299

### Creating a channel from the app fails with 400108
- **Cause:** The application is set to block channel creation from clients, so `GroupChannel.createChannel(params:completionHandler:)` is rejected; the error text in the first case reads "Group channel creation is not allowed from clients." (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:2602; also source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html). 400108 is `nonAuthorized` (source: knowledge/curated/ios/cross-cutting/errors.md).
- **Fix:** Create channels from your server with the Platform API, or ask Sendbird support to allow client-side creation for the application.
- **Cases:** https://community.sendbird.com/t/topic/5679, https://community.sendbird.com/t/is-it-possible-to-forbid-all-users-from-creating-a-channel/5047

## Messages and threads

### Messages look sent but are gone after leaving and reopening the channel
- **Cause:** The channel was created as ephemeral, and an ephemeral channel does not keep its messages.
- **Fix:** Create the channel with `isEphemeral` left at `false` on the channel create params (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:3248).
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

### Messages sent before a user joined are missing
- **Cause:** By default, a member sees only the messages sent after they joined the group channel. This is an application setting (chat history), not an SDK option, so no client code changes it. The cases below come from JavaScript apps; the setting belongs to the application and applies to every platform.
- **Fix:** Turn on chat history for group channels in the dashboard's channel settings. Per the cases, it applies to users who join after it is turned on.
- **Cases:** https://community.sendbird.com/t/error-calling-get-message-by-id-for-message-sent-before-user-joins-a-group-channel/9451, https://community.sendbird.com/t/getting-first-message-of-channel/9507, https://community.sendbird.com/t/chat-history-when-joining-private-group-channel/2237

### UIKit shows an image or video as a generic file
- **Cause:** UIKit picks the message cell from the file message's `type`, which is the MIME type sent in `mimeType`. A type that starts with `image` (except SVG) gets the image cell, one that starts with `video` gets the video cell, and one that starts with `audio` gets the audio or voice cell. Any other value, including an empty one, gets the generic file cell (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Util/SBUUtils.swift#L22-L52).
- **Fix:** Set `mimeType` on `FileMessageCreateParams` to the file's full MIME type, such as `image/jpeg` or `video/mp4` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:2434; also source: knowledge/curated/ios/products/chat.md). UIKit's own `sendFileMessage(fileData:fileName:mimeType:parentMessage:)` passes the value it is given to the same field (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/Channel/SBUBaseChannelViewModel.swift#L348-L352).

## UIKit layout and appearance

### The message input sits in the wrong place when the keyboard opens
- **Cause:** With a custom tab bar (not the one from `UITabBarController`), UIKit can compute the tab bar height wrongly and leave extra space above the keyboard. A UIKit screen wrapped in SwiftUI can also jump to the top because UIKit already accounts for safe area insets.
- **Fix:** For a custom tab bar, override `getAdjustedKeyboardHeight(with:)` and `getTabBarHeight()` in your channel view controller subclass to return the correct values (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:1573, :1574). For a SwiftUI wrapper, apply `.ignoresSafeArea()` (at least the bottom edge) to the wrapped view.
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/113, https://community.sendbird.com/t/uikit-textfield-goes-up-to-the-top-when-user-taps-the-textfield/2193

### After creating a channel, a new channel list covers the whole app instead of opening the channel in place
- **Cause:** When the create-channel screen finishes, its default `createChannelViewModel(_:didCreateChannel:withMessageListParams:)` calls `SendbirdUI.moveToChannel(channelURL:messageListParams:)` without a `rootViewController`. `moveToChannel` then starts from the window's root view controller (or the selected tab of a `UITabBarController` there) and looks for a channel list or channel screen only in the `UINavigationController` it finds at that spot. When your channel list sits somewhere else, for example inside a custom container, nothing is found, and UIKit presents a new `UINavigationController` with a fresh channel list over the root and opens the channel there. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L763-L813 — `moveToChannel`; lines 879–898 `findChannelListViewController`; lines 839–851 the fallback that presents a new channel list) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SelectUser/CreateChannel/SBUCreateChannelViewController.swift#L313-L323)
- **Fix:** Subclass `SBUCreateChannelViewController`, override `createChannelViewModel(_:didCreateChannel:withMessageListParams:)`, and pass a `rootViewController` that `moveToChannel` can search. The method's documentation says to pass your channel list or channel view controller when the hierarchy is complex; the navigation controller that pushed the create-channel screen (UIKit's channel list pushes it on its own navigation controller) also works because the lookup reads its `viewControllers`. Register the subclass once at launch.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

final class InPlaceCreateChannelViewController: SBUCreateChannelViewController {
    override func createChannelViewModel(
        _ viewModel: SBUCreateChannelViewModel,
        didCreateChannel channel: BaseChannel?,
        withMessageListParams messageListParams: MessageListParams?
    ) {
        guard let channelURL = channel?.channelURL else { return }
        SendbirdUI.moveToChannel(
            channelURL: channelURL,
            messageListParams: messageListParams,
            rootViewController: navigationController // the stack that holds your channel list
        )
    }
}

// At launch, before the channel list is shown:
// SBUViewControllerSet.CreateChannelViewController = InPlaceCreateChannelViewController.self
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L750-L767 — `rootViewController` parameter documentation) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/SBUGroupChannelListViewController.swift#L305-L310 — the channel list pushes the create-channel screen) (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:16572 `moveToChannel(channelURL:basedOnChannelList:messageListParams:channelType:rootViewController:)`, :4196 `createChannelViewModel(_:didCreateChannel:withMessageListParams:)`, :16187 `SBUViewControllerSet.CreateChannelViewController`)

### Sendbird SwiftUI screens show two navigation bars
- **Cause:** The Sendbird SwiftUI views host UIKit view controllers that bring their own navigation bar. In SendbirdSwiftUI 1.0.0-beta.1, a SwiftUI navigation bar on the host added a second one.
- **Fix:** Update SendbirdSwiftUI. The release notes list fixes for this in 1.0.0-beta.2 ("Fixed multiple navigationBars appearing issue"), 1.0.1 (an unwanted navigation bar with the `.groupChannelView { }` builder inside a `TabView`), 1.1.3 (a missing navigation bar in a `TabView`), and 1.2.2 (an empty navigation bar above the header when the SDK pushes a channel view created by the `groupChannelView` builder). The `.navigationBarHidden(true)` workaround in the discussion was for 1.0.0-beta.1, and the discussion itself is marked out of date. (source: https://github.com/sendbird/sendbird-swiftui-ios/releases)
- **Cases:** https://github.com/sendbird/sendbird-swiftui-ios/discussions/7, https://community.sendbird.com/t/swiftui-sdk-integration/10082 (fixed in 1.0.0-beta.2 per the staff reply)

### UIKit chrome does not follow the system light or dark appearance on iOS 26
- **Cause:** Liquid Glass chrome follows `SBUTheme.colorScheme` by default, so it keeps the old scheme when the system appearance changes unless the app updates the theme.
- **Fix:** With static theme colors, keep `SBUTheme.liquidGlassAppearance` at `.theme`, call `SBUTheme.set(colorScheme:)` and re-apply your colors on every appearance change, then call `updateStyles()` on the visible screen. With trait-based dynamic `UIColor`s, set `SBUTheme.liquidGlassAppearance` to `.system` once at launch. Setting `SendbirdUI.config.common.isLiquidGlassEnabled` to `false` turns Liquid Glass off (source: SendbirdUIKit 3.36.2 SendbirdUIKit.swiftinterface:14280, :14183, :14184, :14194, :2542, :16525, :3660, :3493; also source: https://github.com/sendbird/sendbird-uikit-ios/discussions/193). The appearance and Liquid Glass switches are iOS 26.0+ APIs, and the case targets UIKit 3.36.0 or later.
- **Cases:** https://github.com/sendbird/sendbird-uikit-ios/discussions/193

## Push

### Every push notification arrives twice
- **Cause:** Sendbird sends one push per registered APNs credential, so two certificates for the same bundle ID produce two notifications.
- **Fix:** Keep one APNs credential per bundle ID in the dashboard.
- **Cases:** https://community.sendbird.com/t/chat-push-notification-is-coming-twice-in-ios/1913, https://community.sendbird.com/t/duplicate-push-notifications/4696

### Push notifications never arrive, for Chat messages or Calls
- **Cause:** The APNs credential in the dashboard does not match the app. The usual reasons are a certificate for another bundle ID, a .p8 key set to Production while the build uses a development token (APNs answers `BadDeviceToken`), or push not being turned on for the application at all.
- **Fix:** Upload a credential for the app's bundle ID and pick the environment that matches the build (Development for debug builds, Production for release builds). Setup steps: knowledge/curated/ios/cross-cutting/push.md.
- **Cases:** https://community.sendbird.com/t/not-receiving-push-notifications-in-ios-after-registering-tokem/4593, https://community.sendbird.com/t/apns-errors-when-using-p8-token/7967, https://github.com/sendbird/sendbird-calls-ios/discussions/27

### Only the most recently used device gets push notifications
- **Cause:** The token was registered with `unique: true`, which removes the user's other tokens (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html — `registerDevicePushToken(_:unique:completionHandler:)`: "register device token after removing exsiting all device tokens of the current user").
- **Fix:** Register with `unique: false` in `SendbirdChat.registerDevicePushToken(_:unique:completionHandler:)` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6399; also source: knowledge/curated/ios/cross-cutting/push.md). For Calls, use `unique: false` in `SendBirdCall.registerVoIPPush(token:unique:completionHandler:)` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:884; also source: knowledge/curated/ios/products/calls.md). The Chat case also says to turn on multi-device push in the dashboard.
- **Cases:** https://community.sendbird.com/t/multi-device-ios-push-notification-support/3024, https://community.sendbird.com/t/notifications-for-multiple-devices/1536

### No push notification shows while the app is open
- **Cause:** Sendbird sends a push notification to a device only while it is disconnected from the server. The table on the push setup page says a single-device user gets the notification "when disconnected from the server and thus offline"; with multi-device support, the dashboard choice decides whether all devices or at least one must be offline. An app in the foreground is usually connected, so no push is sent to it.
- **Fix:** Show in-app alerts from a channel delegate instead. Register one with `SendbirdChat.addChannelDelegate(_:identifier:)` and handle `channel(_:didReceive:)` from `BaseChannelDelegate` (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6376, :867, :868; also source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-channel-delegates/add-or-remove-a-channel-delegate). Delivery rules and the multi-device setting: source: https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials (Step 6 table).

## Calls

### The app is terminated when a VoIP push arrives in the background
- **Cause:** On iOS 13 and later, the system terminates an app that receives a VoIP push without reporting an incoming call to CallKit.
- **Fix:** Forward the PushKit payload to `SendBirdCall.pushRegistry(_:didReceiveIncomingPushWith:for:completionHandler:)` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:883; also source: https://github.com/sendbird/sendbird-calls-ios). In `SendBirdCallDelegate.didStartRinging(_:)`, report the call with CallKit's `reportNewIncomingCall` (source: SendBirdCalls 1.12.3 SendBirdCalls.swiftinterface:650; also source: knowledge/curated/ios/products/calls.md). The public Calls QuickStart sample shows this flow.
- **Cases:** https://community.sendbird.com/t/app-gets-terminated-when-voip-push-is-received-when-app-in-background/701

## Upgrading from v3

### v3 code fails to build after moving to Chat SDK v4
- **Cause:** v4 is a different module with breaking changes. The import is `SendbirdChatSDK` instead of `SendBirdSDK`, the main class `SBDMain` is now `SendbirdChat`, the `SBD` prefix is gone from every type, `SBDError` is now `SBError`, `SBDChannelDelegate` is split into `BaseChannelDelegate`, `GroupChannelDelegate`, and `OpenChannelDelegate`, and each params class is split into create and update params (for example `SBDGroupChannelParams` into `GroupChannelCreateParams` and `GroupChannelUpdateParams`). Query setters were replaced by params classes. The SPM mirror `sendbird-chat-ios-spm` still ships v3 (`SendBirdSDK`), so a project that added it never gets v4.
- **Fix:** Add `https://github.com/sendbird/sendbird-chat-sdk-ios` (product `SendbirdChatSDK`) and remove the v3 package (see knowledge/curated/ios/setup.md). Then follow the guide's steps in order: replace `import SendBirdSDK` with `import SendbirdChatSDK`, replace `SBDError` with `SBError`, replace `SBDMain` with `SendbirdChat`, and remove the remaining `SBD` prefixes. Calls that report "Missing arguments for parameters params" now take a params object. For UIKit, also follow the UIKit migration guide from v2 to v3. Rename tables and the UIKit steps: knowledge/curated/ios/cross-cutting/migration.md. (source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/migration-guide) (source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/miscellaneous/migration-guide/from-version-two) (source: knowledge/curated/ios/setup.md)

## Related

- Error codes: knowledge/curated/ios/cross-cutting/errors.md
- Push setup: knowledge/curated/ios/cross-cutting/push.md
- Common mistakes: knowledge/curated/ios/cross-cutting/pitfalls.md
- Upgrading from Chat SDK v3 or UIKit v2: knowledge/curated/ios/cross-cutting/migration.md
