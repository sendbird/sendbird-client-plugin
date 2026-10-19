<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — push

> APIs + handler shape copied from the public `sendbird-uikit-android` sample (MyFirebaseMessagingService.kt + BaseApplication.kt) and verified via org-wide code search (verified 2026-09-30). The "Handler-based vs manual token registration" snippet was checked with `javap` against the sendbird-chat 4.36.5 AAR and compiled against chat 4.36.5 in a copy of the `tests/android-compile` harness; the handler shape was also verified by pinned/latest Android template compile on 2026-09-22. The logout section was added on 2026-10-11 from `javap` on the 4.36.5 AAR and the Android authentication and FCM pages. Used by `/sendbird-client:push-setup`. Do not invent API.

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

## Logout: unregister this device before disconnecting

Disconnecting is a logout, but unless the push token is unregistered the user still receives push notifications for their group channels. On logout, unregister first and call `SendbirdChat.disconnect` from the completion.

```kotlin
// Handler path: false removes only this device's token; true removes all of the user's tokens.
fun logOut() {
    SendbirdPushHelper.unregisterHandler(false, object : PushRequestCompleteHandler {
        override fun onComplete(isRegistered: Boolean, token: String?) {
            SendbirdChat.disconnect { /* clear user data */ }
        }
        override fun onError(e: SendbirdException) { /* handle the error, then decide whether to disconnect */ }
    })
}

// Manual path (no handler): unregister the token you registered.
fun logOutManual(token: String) {
    SendbirdChat.unregisterPushToken(token) { e ->
        SendbirdChat.disconnect { }
    }
}
```

The handler-based guide shows the same order (unregister in a completion, then `disconnect`), but with `SendbirdPushHelper.unregisterPushHandler`, which the 4.36.5 AAR marks `Deprecated`; `unregisterHandler(Boolean, PushRequestCompleteHandler)` is the current call. Its first parameter is named `unregisterAllTokens` in the AAR.

(source: sendbird-chat-4.36.5.aar `javap -public` com.sendbird.android.push.SendbirdPushHelper — `unregisterHandler(boolean, PushRequestCompleteHandler)`, `javap -v` shows `Deprecated: true` on `unregisterPushHandler` and the `unregisterAllTokens` parameter name; com.sendbird.android.handler.PushRequestCompleteHandler — `onComplete(boolean, String)`, `onError(SendbirdException)`; com.sendbird.android.SendbirdChat — `unregisterPushToken(String, CompletionHandler)`, `unregisterPushTokenAll(CompletionHandler)`, `disconnect(DisconnectHandler)`; source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication; https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/multi-device-support/set-up-push-notifications-for-fcm — reviewed 2026-10-11; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.push/-sendbird-push-helper/index.html; also source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html)

## Open the channel from a notification tap

Sendbird sends Android push as FCM data messages, so your handler builds the notification itself and decides what a tap opens. The `sendbird` entry of `remoteMessage.data` is a JSON string whose `channel.channel_url` names the channel. With UIKit, `ChannelListActivity.newRedirectToChannelIntent(context, channelUrl)` opens the channel list and moves straight into that channel. The UIKit sample also wraps a redirect intent for the channel in the notification's `PendingIntent`.

## Delivery receipts for offline members

A member who is offline gets the message only as a push. Call `SendbirdChat.markAsDelivered(remoteMessage.data)` in your handler's `onMessageReceived` so the sender sees it as delivered; online members are marked automatically. The docs require `SendbirdChat.init(...)` in `Application.onCreate()`, or the call may not work for a push that arrives while the app is terminated.

```kotlin
import android.app.PendingIntent
import android.content.Context
import com.google.firebase.messaging.RemoteMessage
import com.sendbird.android.SendbirdChat
import com.sendbird.android.push.SendbirdPushHandler
import com.sendbird.uikit.activities.ChannelListActivity
import org.json.JSONObject

class TapToChannelPushHandler : SendbirdPushHandler() {
    override val isUniquePushToken: Boolean
        get() = false
    override fun onNewToken(newToken: String?) { }
    override fun onMessageReceived(context: Context, remoteMessage: RemoteMessage) {
        val payload = remoteMessage.data["sendbird"] ?: return
        SendbirdChat.markAsDelivered(remoteMessage.data)   // delivery receipt for this offline member
        val channelUrl = JSONObject(payload).getJSONObject("channel").getString("channel_url")
        val openChannel = ChannelListActivity.newRedirectToChannelIntent(context, channelUrl)
        val tap = PendingIntent.getActivity(
            context, channelUrl.hashCode(), openChannel,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        // Build your notification with setContentIntent(tap), then show it.
    }
}
```

(source: https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/multi-device-support/set-up-push-notifications-for-fcm — parsing `sendbird` and `channel_url`) (source: https://sendbird.com/docs/chat/sdk/v4/android/message/marking-messages-as-delivered-in-a-group-channel/mark-messages-as-delivered) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/common/fcm/MyFirebaseMessagingService.kt#L45-L67 — `markAsDelivered` and the tap intent at lines 103-117) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/activities/ChannelListActivity.java#L62) (source: sendbird-chat 4.36.5 AAR, `javap` on `com.sendbird.android.SendbirdChat` — `markAsDelivered(Map)`)

## Android 13 and later: the notification permission

On Android 13 (API level 33) and later, showing notifications needs the `POST_NOTIFICATIONS` runtime permission. Declare `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` in the app's manifest and request it at runtime; until the user grants it, the notifications your handler builds are not shown. The Chat SDK and UIKit AARs do not declare it in their manifests, and UIKit's source never requests it; the UIKit sample app declares it in its own manifest and requests it in its home Activity.

```kotlin
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

class HomeActivity : ComponentActivity() {
    private val askNotifications = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        // granted == false: explain in your UI why chat notifications are off
    }

    fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) return
        askNotifications.launch(permission)
    }
}
```

(source: https://developer.android.com/develop/ui/views/notifications/notification-permission) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/basic/BasicHomeActivity.kt#L49-L62 — the sample's runtime request; the declaration is in uikit-samples/src/main/AndroidManifest.xml line 8) (source: sendbird-chat 4.36.5 and uikit 3.26.3 AAR `AndroidManifest.xml` — no `POST_NOTIFICATIONS`)

## Read the payload and build the notification yourself

In the docs and in the public UIKit sample, the app's own messaging service builds the notification from the FCM data message (see the `sendNotification(...)` step in the FCM guide). A Sendbird push carries a JSON string under the `sendbird` data key. The docs read the title from its `push_title` field, the body from its `message` field, and the channel to open from `channel.channel_url`; put those on the notification you build.

```kotlin
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

data class SendbirdPush(val title: String, val body: String, val channelUrl: String)

fun parseSendbirdPush(remoteMessage: RemoteMessage): SendbirdPush? {
    val raw = remoteMessage.data["sendbird"] ?: return null // not a Sendbird push
    val sendbird = JSONObject(raw)
    return SendbirdPush(
        title = sendbird.optString("push_title"),
        body = sendbird.optString("message"),
        channelUrl = sendbird.getJSONObject("channel").getString("channel_url"),
    )
}
```
(source: https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/managing-push-notifications/set-up-push-notifications-for-fcm)

## Mark a push as delivered

`SendbirdPushHelper.markPushNotificationAsDelivered(remoteMessage.data)` reports to Sendbird that a push reached the device. `SendbirdChat.init()` must already have run, and the docs require it to be called in `Application.onCreate()`, because a push can arrive while no Activity exists. If your app uses multi-device support with a `SendbirdPushHandler` (or `SendbirdHmsPushHandler`), the SDK makes this call for you.

```kotlin
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.sendbird.android.push.SendbirdPushHelper

class MyMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // SendbirdChat.init() ran in Application.onCreate() before this point.
        SendbirdPushHelper.markPushNotificationAsDelivered(remoteMessage.data)
    }
}
```
(source: https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/marking-push-notifications-as-delivered/mark-push-notifications-as-delivered) (source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.push/-sendbird-push-helper/index.html)

## Payload size (FCM limit)

Sendbird delivers Android push as FCM data messages, and the `sendbird` payload carries message details — for a FILE message this includes a `files` array with file data. FCM rejects a message whose payload (keys and values together) exceeds 4096 bytes ("Message too big", `INVALID_ARGUMENT`), and Sendbird can't raise that limit. Keep what you attach to messages small, and trim optional payload fields in the dashboard's notification settings; don't assume large file metadata will always fit.

(source: https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type; https://firebase.google.com/docs/cloud-messaging/error-codes; https://sendbird.com/docs/chat/sdk/v4/android/push-notifications/managing-push-notifications/set-up-push-notifications-for-fcm)

## Setup checklist
- Add the FCM dependency. Apply the `com.google.gms.google-services` Gradle plugin only when `app/google-services.json` exists in the project. With the plugin applied and the file absent, the build fails with "File google-services.json is missing" (the plugin's default strategy is `ERROR`). Never apply it unconditionally and never invent a placeholder `google-services.json`. Without the file, leave the plugin out (or apply it inside `if (file("google-services.json").exists()) { ... }` in `app/build.gradle(.kts)`, so adding the file later is enough), and list "download `google-services.json` from your Firebase project in the Firebase console and put it in `app/`" in the customer's hand-off steps. For variants that really do not need it, the plugin's `WARN` strategy for a missing file (set in the plugin's Gradle configuration block; see its README) turns the failure into a warning, but a build without the file has no Firebase configuration at runtime, so push does not work until the file is added.
  (source: https://github.com/google/play-services-plugins/blob/4bde1b858612402ae5452cbef107b141afd44ef5/google-services-plugin/src/main/kotlin/com/google/gms/googleservices/GoogleServicesTask.kt#L60-L82) (source: https://github.com/google/play-services-plugins/blob/4bde1b858612402ae5452cbef107b141afd44ef5/google-services-plugin/README.md)
- Upload the FCM credentials by following the official dashboard push configuration guide. Do not guess the current dashboard path.
- Register the handler after init; the SDK sends the token to Sendbird.

## Pitfalls
- Register the handler after `SendbirdChat.init`.
- You do not declare a messaging service yourself: the Chat SDK's own manifest already declares `com.sendbird.android.push.SendbirdFirebaseMessagingService` and merges into the app, and `SendbirdPushHandler` is not a `Service`. (source: sendbird-chat 4.36.5 AAR `AndroidManifest.xml`)
- On logout, unregister this device's token before `disconnect`; a disconnected user still receives push (see Logout: unregister this device before disconnecting).
- Credentials are secrets — never hard-code or commit `google-services.json` secrets, and never create the file yourself; it comes from the customer's Firebase project.

## Related
- Chat: knowledge/curated/android/products/chat.md
- AI Agent push: knowledge/curated/android/products/ai-agent.md
