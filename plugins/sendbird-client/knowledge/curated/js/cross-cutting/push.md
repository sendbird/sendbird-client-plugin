<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — push

> Push token APIs read from `@sendbird/chat`'s shipped types (`lib/__definition.d.ts`); the React Native tap-handling pattern follows Sendbird's public RN UIKit sample. Verified 2026-09-30; the logout section was added on 2026-10-11, and the React Native UIKit automatic registration section on 2026-10-23 from the `sendbird-uikit-react-native` v3.12.9 source. Used by `/sendbird-client:push-setup`. Do not invent API.

## Overview

On React Native (and hybrid) the device gets an FCM (Android) or APNs (iOS) token from the native layer; register it with Sendbird after the user connects. In a browser, the Chat SDK does not support push notifications: the push overview says only a hybrid app built with React Native can handle push with the Chat SDK, and that web apps delivered through browsers such as Chrome and Edge can build their own notifications from Sendbird's webhooks instead. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/push-notifications/overview-push-notifications)

## Register / unregister a push token

```ts
// FCM (Android / RN Android)
await sb.registerFCMPushTokenForCurrentUser(fcmToken);
await sb.unregisterFCMPushTokenForCurrentUser(fcmToken);
await sb.unregisterFCMPushTokenAllForCurrentUser();

// APNs (iOS / RN iOS)
await sb.registerAPNSPushTokenForCurrentUser(apnsToken);
await sb.unregisterAPNSPushTokenForCurrentUser(apnsToken);
await sb.unregisterAPNSPushTokenAllForCurrentUser();
```

Register and single-token unregister return `PushTokenRegistrationState`; the `...AllForCurrentUser()` variants return nothing (`Promise<void>`). The register methods take an optional `PushTokenRegistrationDetails` second arg that tracks device info. (source: @sendbird/chat lib/__definition.d.ts — `registerFCMPushTokenForCurrentUser`, `registerAPNSPushTokenForCurrentUser`, and their unregister variants; 4.22.13 lines 4499-4532)

## Logout: unregister this device before disconnecting

`sb.disconnect()` does not stop push: a disconnected user still receives push notifications for their group channels. On logout, unregister this device's token first and disconnect after it resolves.

```ts
// Android (FCM) token; use unregisterAPNSPushTokenForCurrentUser(apnsToken) for an iOS token.
await sb.unregisterFCMPushTokenForCurrentUser(fcmToken);
await sb.disconnect();
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication — Disconnect from the Sendbird server, reviewed 2026-10-11; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat.disconnect()` 4388, `unregisterFCMPushTokenForCurrentUser(token)` 4508, `unregisterAPNSPushTokenForCurrentUser(token)` 4528 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

## One device or many (`unique`)

The register methods take `PushTokenRegistrationDetails` as their second argument. Its `unique` field decides what happens to the user's other tokens: with `unique: true`, all tokens previously registered for the user are removed and only this one is kept, so only the most recently registered device gets push; with `unique: false`, the token is added alongside the others. If only the last device a user signed in on gets push, check for `unique: true`, and turn on multi-device support in the dashboard.

```ts
await sb.registerFCMPushTokenForCurrentUser(fcmToken, { unique: false });
await sb.registerAPNSPushTokenForCurrentUser(apnsToken, { unique: false });
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html) (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:3952-3970 — `PushTokenRegistrationDetails.unique` ; lib/__definition.d.ts:4499-4502, 4519-4522)

## Delivery receipts for messages that arrived as push

A message delivered to an online member is marked as delivered automatically. For a member who was offline, the docs say to call `markAsDelivered` when the member brings the app to the foreground or comes back online: `sb.groupChannel.markAsDelivered(channelUrl)` does it by channel URL, and `channel.markAsDelivered()` on a channel you already have. Online members then get `onUndeliveredMemberStatusUpdated` on their group channel handler. `sb.markPushNotificationAsDelivered(pushData)` is a different call: its doc comment says it is for push delivery tracking only and does not mark the message as delivered.

```ts
// For example in a React Native AppState 'active' listener, after connect has resolved:
await sb.groupChannel.markAsDelivered(CHANNEL_URL);
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/marking-messages-as-delivered-in-a-group-channel/mark-messages-as-delivered) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html) (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:6338-6342 — `GroupChannelModule.markAsDelivered(channelUrl)` ; lib/__definition.d.ts:2134 — `GroupChannel.markAsDelivered()` ; lib/__definition.d.ts:4533-4540 — `markPushNotificationAsDelivered`)

## Push only for mentions (push trigger option)
A user can limit push notifications to messages that mention them, for every channel or for one channel. `PushTriggerOption` is one enum exported from `@sendbird/chat`; the user-level setter takes `ALL`, `MENTION_ONLY`, or `OFF`, and the channel-level setter also takes `DEFAULT`, which makes the channel follow the user-level setting (the default).

```ts
import { PushTriggerOption } from '@sendbird/chat';
import type { GroupChannel } from '@sendbird/chat/groupChannel';

async function mentionsOnly(channel?: GroupChannel) {
  if (channel) {
    await channel.setMyPushTriggerOption(PushTriggerOption.MENTION_ONLY); // this channel only
  } else {
    await sb.setPushTriggerOption(PushTriggerOption.MENTION_ONLY); // all channels without their own setting
  }
}
```
The docs' examples pass the string `'mention_only'`; in TypeScript use the enum member, because a string literal is not assignable to the enum type. Like every push, these apply only while the user is disconnected. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/push-notifications/configuring-preferences/push-notification-preferences — option tables ; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `PushTriggerOption` 3992-3997, `SendbirdChat.setPushTriggerOption` 4640, `GroupChannel.setMyPushTriggerOption` 2200 ; index.d.ts:66 — root export)

## Setup checklist

- React Native: obtain the FCM/APNs token via the native push module, then register it after connect. With React Native UIKit, connect does this for you (see "React Native UIKit: automatic token registration").
- Upload FCM/APNs credentials by following the official dashboard push configuration guide. Do not guess the current dashboard path.

## React Native UIKit: automatic token registration

With React Native UIKit, the app usually writes no token registration code. `chatOptions.enableAutoPushTokenRegistration` on `SendbirdUIKitContainer` defaults to `true`. While it is on, UIKit's `useConnection().connect` asks for the push permission, gets the token from `platformServices.notification` (`getFCMToken` on Android, `getAPNSToken` on iOS), and registers it for the user after connect; `useConnection().disconnect` unregisters it before it disconnects. So an app that connects and disconnects through `useConnection` already registers and unregisters this device: do not add a second registration path with the register calls above, and do not set the option to `false` to replace it. What remains is native: a notification service that can return a token (the public sample builds it with `createNativeNotificationService` from `@react-native-firebase/messaging` and `react-native-permissions`), the Firebase files, and the dashboard credentials.

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L69 — `AUTO_PUSH_TOKEN_REGISTRATION: true` ; same file lines 232-233 — `chatOptions.enableAutoPushTokenRegistration ?? SendbirdUIKit.DEFAULT.AUTO_PUSH_TOKEN_REGISTRATION`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/hooks/useConnection.ts#L48-L53 — register after `sdk.connect` ; lines 94-101 — unregister, then `sdk.disconnect()`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/hooks/usePushTokenRegistration.ts — permission check, `getAPNSToken` / `getFCMToken`, `registerAPNSPushTokenForCurrentUser` / `registerFCMPushTokenForCurrentUser`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/sample/src/factory/index.ts#L35-L38 — `createNativeNotificationService({ messagingModule: RNFBMessaging, permissionModule: Permissions })`)

## React Native: opening a channel from a push tap

Tap handling belongs to the push library you use, not to the Chat SDK. Sendbird's public RN UIKit sample does it like this:

- iOS: set `UNUserNotificationCenter.current().delegate` in `AppDelegate` and forward `userNotificationCenter(_:didReceive:withCompletionHandler:)` to `RNCPushNotificationIOS.didReceive(response)`; then read cold-start taps with `PushNotificationIOS.getInitialNotification()` and later taps with `PushNotificationIOS.addEventListener('localNotification', …)`, checking `data.userInteraction === 1`. If the delegate is not set, taps never reach JavaScript.
- Android: Sendbird sends data-only FCM messages, so the sample displays them itself (`messaging().setBackgroundMessageHandler` → Notifee) and handles taps with Notifee's `onForegroundEvent` / `onBackgroundEvent`.

Use `@sendbird/uikit-utils` to recognise and parse the payload:

```ts
import { isSendbirdNotification, parseSendbirdNotification } from '@sendbird/uikit-utils';

function channelUrlFromPushData(data?: { [key: string]: string | object }) {
  if (!isSendbirdNotification(data)) return undefined;
  return parseSendbirdNotification(data).channel.channel_url;
}
```

(source: github.com/sendbird/sendbird-uikit-react-native v3.12.9 sample/src/libs/notification.ts, sample/ios/SendbirdUIKitSample/AppDelegate.swift ; @sendbird/uikit-utils@3.12.9 lib/typescript/src/sendbird/message.d.ts:19-22)

## No push while the app is open (React Native)

Sendbird sends a push only to a device that is disconnected. The delivery table in the push setup docs says a single-device user gets the notification "when disconnected from the server and thus offline"; with multi-device support, the dashboard setting decides whether all devices or at least one must be offline. A React Native app in the foreground has called `sb.setForegroundState()` and is connected, so it gets no push. Show in-app alerts from the `onMessageReceived` callback of a `GroupChannelHandler` instead, and keep push for the background.

```ts
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';

sb.groupChannel.addGroupChannelHandler('in-app-alerts', new GroupChannelHandler({
  onMessageReceived: (_channel, message) => { /* show an in-app banner for message */ },
}));
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelModule.html) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelHandler.html) (source: https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials — Step 6 table; the delivery rule is server-side) (source: @sendbird/chat 4.22.13 lib/__definition.d.ts:5426 — `onMessageReceived` ; knowledge/curated/js/hosts/react-native.md — App lifecycle)

## Pitfalls

- Register after the user connects; tokens are per-user.
- On logout, unregister this device's token before `sb.disconnect()`; a disconnected user still receives push.
- Use the FCM methods for Android tokens and the APNS methods for iOS tokens — don't mix.
- The Chat SDK has no browser push; for web notifications use webhooks (see Overview).

## Related

- Chat connect: knowledge/curated/js/products/chat.md
