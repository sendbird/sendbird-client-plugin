<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — push

> Push token APIs read from `@sendbird/chat`'s shipped types (`lib/__definition.d.ts`); the React Native tap-handling pattern follows Sendbird's public RN UIKit sample. Verified 2026-09-30. Used by `/sendbird-client:push-setup`. Do not invent API.

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

All return `PushTokenRegistrationState`; an optional `PushTokenRegistrationDetails` second arg tracks device info. (source: @sendbird/chat lib/__definition.d.ts — `registerFCMPushTokenForCurrentUser`, `registerAPNSPushTokenForCurrentUser`, and their unregister variants)

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
- Use the FCM methods for Android tokens and the APNS methods for iOS tokens — don't mix.
- Browser web push (service worker) is a separate setup, not these token methods.

## Related

- Chat connect: knowledge/curated/js/products/chat.md
