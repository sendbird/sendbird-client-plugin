<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — push

> Push token APIs read from `@sendbird/chat`'s shipped types (`lib/__definition.d.ts`); the React Native tap-handling pattern follows Sendbird's public RN UIKit sample. Verified 2026-09-30; the logout section was added on 2026-10-11. Used by `/sendbird-client:push-setup`. Do not invent API.

## Overview

On React Native (and hybrid) the device gets an FCM (Android) or APNs (iOS) token from the native layer; register it with Sendbird after the user connects. Browser web push is a separate service-worker flow.

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

A push token identifies one app install, so keep it registered only for the user who is signed in on that device. `sb.disconnect()` does not stop push: a disconnected user still receives push notifications for their group channels. On logout, unregister this device's token first and disconnect after it resolves; otherwise the next user on the device can receive the previous user's notifications.

```ts
// Android (FCM) token; use unregisterAPNSPushTokenForCurrentUser(apnsToken) for an iOS token.
await sb.unregisterFCMPushTokenForCurrentUser(fcmToken);
await sb.disconnect();
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication — Disconnect from the Sendbird server, reviewed 2026-10-11; `@sendbird/chat` 4.22.13 `lib/__definition.d.ts`: `SendbirdChat.disconnect()` 4388, `unregisterFCMPushTokenForCurrentUser(token)` 4508, `unregisterAPNSPushTokenForCurrentUser(token)` 4528 — verified 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html)

## Setup checklist

- React Native: obtain the FCM/APNs token via the native push module, then register it after connect.
- Upload FCM/APNs credentials by following the official dashboard push configuration guide. Do not guess the current dashboard path.

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

## Pitfalls

- Register after the user connects; tokens are per-user.
- On logout, unregister this device's token before `sb.disconnect()`; a disconnected user still receives push.
- Use the FCM methods for Android tokens and the APNS methods for iOS tokens — don't mix.
- Browser web push (service worker) is a separate setup, not these token methods.

## Related

- Chat connect: knowledge/curated/js/products/chat.md
