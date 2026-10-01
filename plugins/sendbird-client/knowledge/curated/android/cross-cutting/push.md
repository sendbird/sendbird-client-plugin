<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — push

> APIs + handler shape copied from the public `sendbird-uikit-android` sample (MyFirebaseMessagingService.kt + BaseApplication.kt) and verified via org-wide code search (verified 2026-09-30). The "Handler-based vs manual token registration" snippet was checked with `javap` against the sendbird-chat 4.36.5 AAR and compiled against chat 4.36.5 in a copy of the `tests/android-compile` harness; the handler shape was also verified by pinned/latest Android template compile on 2026-09-22. Used by `/sendbird-client:push-setup`. Do not invent API.

## Overview
Android push uses FCM (or HMS on Huawei). Subclass `SendbirdPushHandler`, register it with `SendbirdPushHelper.registerHandler(...)`, and the SDK registers the FCM token automatically. Upload your FCM server key / service account on the dashboard.

## Push handler (FCM)
```kotlin
import com.sendbird.android.push.SendbirdPushHandler
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : SendbirdPushHandler() {
    override val isUniquePushToken: Boolean = false
    override fun onNewToken(newToken: String?) {
        // SDK registers this token with Sendbird automatically
    }
    override fun onMessageReceived(context: Context, remoteMessage: RemoteMessage) {
        // Build a local notification + deep link to the channel
    }
}
```
(source: sendbird-uikit-android sample MyFirebaseMessagingService.kt — `SendbirdPushHandler`, `onNewToken`, `onMessageReceived`)

## Register the handler
```kotlin
import com.sendbird.android.push.SendbirdPushHelper

SendbirdPushHelper.registerHandler(MyFirebaseMessagingService())
```
(source: sendbird-uikit-android sample BaseApplication.kt — `SendbirdPushHelper.registerHandler(...)`)

## Handler-based vs manual token registration

Pick one path. With a `SendbirdPushHandler` subclass registered through `SendbirdPushHelper.registerHandler(...)`, the handler path carries the FCM token to Sendbird — the handler-based guides never call `registerPushToken` themselves. Without a handler, register the token yourself with `SendbirdChat.registerPushToken(token) { status, e -> }` (an overload taking `unique: Boolean` also exists); `PushTokenRegistrationStatus.PENDING` means the user wasn't connected yet, so register again after `connect` succeeds. `alwaysReceiveMessage()` is a method you override on your `SendbirdPushHandler` (not a `SendbirdChat` option): the default `false` delivers push only while the app is in the background, and `true` also delivers it in the foreground.

```kotlin
class MyFirebaseMessagingService : SendbirdPushHandler() {
    override val isUniquePushToken: Boolean
        get() = false
    override fun onNewToken(newToken: String?) { }
    override fun onMessageReceived(context: Context, remoteMessage: RemoteMessage) { }
    // Default false: push only while the app is in the background.
    override fun alwaysReceiveMessage(): Boolean = true
}

// Manual path (no handler):
SendbirdChat.registerPushToken(token) { status, e ->
    if (e == null && status == PushTokenRegistrationStatus.PENDING) {
        // Not connected yet — register again after connect succeeds.
    }
}
```

(source: sendbird-chat-4.36.5.aar javap com.sendbird.android.push.SendbirdPushHandler / com.sendbird.android.SendbirdChat; https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/multi-device-support/set-up-push-notifications-for-fcm; https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/managing-push-notifications/set-up-push-notifications-for-fcm)

## Payload size (FCM limit)

Sendbird delivers Android push as FCM data messages, and the `sendbird` payload carries message details — for a FILE message this includes a `files` array with file data. FCM rejects a message whose payload (keys and values together) exceeds 4096 bytes ("Message too big", `INVALID_ARGUMENT`), and Sendbird can't raise that limit. Keep what you attach to messages small, and trim optional payload fields in the dashboard's notification settings; don't assume large file metadata will always fit.

(source: https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type; https://firebase.google.com/docs/cloud-messaging/error-codes; https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/managing-push-notifications/set-up-push-notifications-for-fcm)

## Setup checklist
- Add the Firebase config (`google-services.json`) + FCM dependency.
- Upload the FCM credentials by following the official dashboard push configuration guide. Do not guess the current dashboard path.
- Register the handler after init; the SDK sends the token to Sendbird.

## Pitfalls
- Register the handler after `SendbirdChat.init`.
- Declare the messaging service in `AndroidManifest.xml`.
- Credentials are secrets — never hard-code or commit `google-services.json` secrets.

## Related
- Chat: knowledge/curated/android/products/chat.md
- AI Agent push: knowledge/curated/android/products/ai-agent.md
