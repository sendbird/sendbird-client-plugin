<!-- last-verified-against: sendbird-calls-android 1.12.5 -->
<!-- status: populated -->
# android calls

> Verified against the public mirror `sendbird/sendbird-calls-android` (README implementation guide, verified 2026-06-09). Compile NOT run in-repo (no Android/Java toolchain) — code quoted verbatim. 1.12.5 CHANGELOG reviewed 2026-09-28 — only local-recording pipeline fixes; none of the cited init/authenticate/listener/dial symbols changed. Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-calls-android

## Overview
Sendbird Calls adds voice/video calls. **Direct calls** are 1:1: dial a callee's user ID, their devices ring, accepting connects.

## Install (Gradle)
- `implementation 'com.sendbird.sdk:sendbird-calls:1.12.5'` (or `1.+`).

## Camera and microphone permissions
The SDK's own manifest declares `CAMERA`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH`, `BLUETOOTH_CONNECT`, `INTERNET`, and `ACCESS_NETWORK_STATE` (sendbird-calls 1.12.5 AAR `AndroidManifest.xml`, read 2026-10-17), so the manifest merger adds them to the app; the docs list the same seven `uses-permission` lines for the app's `AndroidManifest.xml`. At runtime, Android 6.0 and later needs `CAMERA` and `RECORD_AUDIO`, and an app targeting Android 12 or later also needs `BLUETOOTH_CONNECT`. Ask for them before the first dial or accept. (source: https://sendbird.com/docs/calls/sdk/v1/android/getting-started/make-first-call — Step 3)

## Initialize + authenticate
```java
SendBirdCall.init(getApplicationContext(), APP_ID);

AuthenticateParams params = new AuthenticateParams(USER_ID)
    .setAccessToken(ACCESS_TOKEN);
SendBirdCall.authenticate(params, (user, e) -> {
    if (e == null) {
        // authenticated
    }
});
```
Register a push token via `SendBirdCall.registerPushToken(...)`; incoming calls need it even while the app is open (see "Incoming calls need push" below). (source: sendbird-calls-android README §authenticate)

## Handle incoming calls
```java
SendBirdCall.addListener(UNIQUE_HANDLER_ID, new SendBirdCallListener() {
    @Override public void onRinging(DirectCall call) { /* incoming 1:1 call */ }
    @Override public void onInvitationReceived(RoomInvitation invitation) { /* incoming group-room invitation */ }
});
```
(source: sendbird-calls 1.12.4 — `SendBirdCallListener` has TWO required abstract methods, `onRinging(DirectCall)` + `onInvitationReceived(RoomInvitation)`, verified via javap of the published AAR 2026-06-22. `RoomInvitation` = `com.sendbird.calls.RoomInvitation`.)

## Incoming calls need push, also while the app is open
The Authentication docs: "WebSocket connections with Sendbird server are made only when there is an ongoing direct call or group call, therefore authenticating won't create unnecessary WebSocket connections. Also, unless you have integrated push notifications to your application, new incoming calls won't be delivered through WebSocket." (source: https://sendbird.com/docs/calls/sdk/v1/android/features/authentication — "WebSocket") The repository README says foreground calls arrive through the SDK's own connection; a test on 2026-10-17 matched the Authentication docs instead: an emulator app (sendbird-calls 1.12.5, no FCM) authenticated, dialed a browser that answered, and connected, but a call from the browser to it never raised `onRinging`. So an app that must receive calls needs the FCM wiring below, and the customer's Firebase project and dashboard credentials for it.

## Receive calls in the background or after the app was closed (FCM)
A device without a live Calls connection gets incoming calls through FCM. The docs' steps: upload the FCM service account key in the dashboard, register the FCM token with `SendBirdCall.registerPushToken(...)` from `onNewToken` (the overload to use is below), and pass every FCM message to `SendBirdCall.handleFirebaseMessageData(remoteMessage.getData())`, which returns `true` for a Calls push and `false` for any other push. (source: https://sendbird.com/docs/calls/sdk/v1/android/features/push-notifications)

The SDK then raises `onRinging` on a listener added with `SendBirdCall.addListener(...)`. When FCM starts the app process, only `Application.onCreate` has run, so the public Direct Call QuickStart calls `SendBirdCall.init(...)` and adds the listener there. Its FCM service registers the token only when `SendBirdCall.currentUser` is set and otherwise saves it for after sign-in. (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/java/com/sendbird/calls/quickstart/BaseApplication.kt#L27-L61) (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/java/com/sendbird/calls/quickstart/fcm/MyFirebaseMessagingService.kt#L12-L31)

```kotlin
import android.app.Application
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.sendbird.calls.DirectCall
import com.sendbird.calls.RoomInvitation
import com.sendbird.calls.SendBirdCall
import com.sendbird.calls.SendBirdException
import com.sendbird.calls.handler.CompletionHandler
import com.sendbird.calls.handler.SendBirdCallListener
import com.sendbird.calls.internal.PushTokenType

class CallsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Runs again when FCM starts the process for an incoming call.
        if (SendBirdCall.init(applicationContext, APP_ID)) {
            SendBirdCall.addListener("incoming-calls", object : SendBirdCallListener() {
                override fun onRinging(call: DirectCall) {
                    // Show the incoming-call UI (see the notification notes below).
                }
                override fun onInvitationReceived(invitation: RoomInvitation) {}
            })
        }
    }
}

class CallsMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        if (SendBirdCall.handleFirebaseMessageData(remoteMessage.data)) return
        // Not a Calls push: handle your other notifications here.
    }

    override fun onNewToken(token: String) {
        if (SendBirdCall.currentUser == null) return   // register after authenticate instead
        SendBirdCall.registerPushToken(token, PushTokenType.FCM_VOIP, false, object : CompletionHandler {
            override fun onResult(e: SendBirdException?) {}
        })
    }
}
```

The three-argument `registerPushToken(token, unique, handler)` shown on the docs page is deprecated since 1.11.0; the compiler names the replacement, `registerPushToken(pushToken, pushTokenType, unique, handler)`, and the QuickStart passes `PushTokenType.FCM_VOIP` (`com.sendbird.calls.internal.PushTokenType`, values `FCM_VOIP` and `HMS_VOIP`). (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/java/com/sendbird/calls/quickstart/utils/PushUtils.kt#L34-L50) (sendbird-calls 1.12.5 `javap -public com.sendbird.calls.SendBirdCall`: `init(Context, String)` returns boolean, `getCurrentUser()`, `registerPushToken(String, PushTokenType, boolean, CompletionHandler)`, `addListener(String, SendBirdCallListener)`, `handleFirebaseMessageData(Map<String, String>)` returns boolean; `SendBirdCallListener` is an abstract class with `onRinging(DirectCall)` and `onInvitationReceived(RoomInvitation)`; `CompletionHandler.onResult(SendBirdException)`; deprecation message from `compile-snippets-android.sh`)

**Showing the ringing call.** The SDK does not draw a notification for you; the QuickStart does it in its own foreground service (`CallService`):
- `onRinging` starts the service with `startForegroundService`. The service posts a `NotificationCompat.CATEGORY_CALL` notification with `PRIORITY_HIGH` on an `IMPORTANCE_HIGH` channel, with accept and decline actions and `setFullScreenIntent(...)` for the ringing screen. (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/java/com/sendbird/calls/quickstart/call/CallService.kt#L83-L139)
- It calls `startForeground` with `FOREGROUND_SERVICE_TYPE_PHONE_CALL` while ringing, and adds `FOREGROUND_SERVICE_TYPE_MICROPHONE` only after the call connects. The sample's comment says that including the microphone type while the app is still in the background throws a `SecurityException` on Android 15+. (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/java/com/sendbird/calls/quickstart/call/CallService.kt#L150-L167)
- Its manifest declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_PHONE_CALL`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK` and `MANAGE_OWN_CALLS`, and registers the service with `android:foregroundServiceType="phoneCall|microphone"`. (source: https://github.com/sendbird/quickstart-calls-directcall-android/blob/1e8cf929f0a891b93bc31ed9b394525a209520ac/directcall-kotlin/app/src/main/AndroidManifest.xml#L7-L93)

## Make a call
```java
DialParams params = new DialParams(CALLEE_ID);
DirectCall call = SendBirdCall.dial(params, (directCall, e) -> {
    if (e == null) { /* dialing */ }
});
```
(source: sendbird-calls-android README §"make a call")

## Receive a call (accept or decline)
Set the call's `DirectCallListener` in `onRinging`, then accept with `accept(...)` or decline with `end()`; the SDK sets up the media session after an accept.

```kotlin
import com.sendbird.calls.AcceptParams
import com.sendbird.calls.CallOptions
import com.sendbird.calls.DirectCall
import com.sendbird.calls.RoomInvitation
import com.sendbird.calls.SendBirdCall
import com.sendbird.calls.handler.DirectCallListener
import com.sendbird.calls.handler.SendBirdCallListener

SendBirdCall.addListener("incoming-calls", object : SendBirdCallListener() {
    override fun onRinging(call: DirectCall) {
        call.setListener(object : DirectCallListener() {
            override fun onConnected(call: DirectCall) {}
            override fun onEnded(call: DirectCall) {}
        })
        // Video when the caller placed a video call; call.end() declines instead.
        val options = CallOptions().setAudioEnabled(true).setVideoEnabled(call.isVideoCall)
        call.accept(AcceptParams().setCallOptions(options))
    }
    override fun onInvitationReceived(invitation: RoomInvitation) {}
})
```

(source: https://sendbird.com/docs/calls/sdk/v1/android/getting-started/make-first-call — Step 10 "Receive a call") (sendbird-calls 1.12.5 `javap -public`: `DirectCall.isVideoCall()`, `setListener(DirectCallListener)`, `accept(AcceptParams)`, `end()`; `DirectCallListener` is abstract with `onConnected(DirectCall)` and `onEnded(DirectCall)`; `CallOptions.setAudioEnabled(boolean)` / `setVideoEnabled(boolean)`; `AcceptParams.setCallOptions(CallOptions)`)

## End a call
`call.end()` declines a ringing call and hangs up a connected one; when the caller ends before the callee answers, the call is canceled. `onEnded` then fires on both sides. (source: https://sendbird.com/docs/calls/sdk/v1/android/getting-started/make-first-call — Step 10)

`templates/android/view/calls/SetupCalls.java` wraps all of this (permissions list, dial, accept, end, sign-out); `templates/android/compose/calls/DirectCallVideo.kt` adds the call state and the video views for Compose.

## Sign out
On logout, deauthenticate the user so this device stops receiving their calls:

```kotlin
import com.sendbird.calls.SendBirdCall
import com.sendbird.calls.SendBirdException
import com.sendbird.calls.handler.CompletionHandler

SendBirdCall.deauthenticate(object : CompletionHandler {
    override fun onResult(e: SendBirdException?) {
        // signed out of Calls
    }
})
```

`SendBirdCall.deauthenticate(CompletionHandler)` is static; `CompletionHandler.onResult(SendBirdException)` reports the result. (source: sendbird-calls 1.12.5 `javap -public com.sendbird.calls.SendBirdCall` and `com.sendbird.calls.handler.CompletionHandler`)

## Manual steps (what a Calls hand-off may list)
Only these Calls steps need something outside the project, and each has a source:
- **App ID:** create a Sendbird application and copy its App ID from the dashboard; it is case-sensitive. (source: https://sendbird.com/docs/calls/sdk/v1/android/getting-started/make-first-call)
- **Token server, only when the app signs users in with tokens:** access or session tokens are issued through the Chat Platform API, not the dashboard. (source: https://sendbird.com/docs/calls/sdk/v1/android/features/authentication)
- **Push credentials, to receive calls:** turn on push notifications and add the FCM credential in the dashboard (Settings > Application > Push notifications), and test on a device with the customer's Firebase project. (source: https://sendbird.com/docs/calls/sdk/v1/android/features/push-notifications)

None of these pages has a dashboard step that enables or activates Calls (checked 2026-10-17). Do not tell the customer to "enable Calls in the dashboard", and do not add any other dashboard step that no page cited here lists.

## Pitfalls
- Add the listener before expecting `onRinging`.
- App ID from BuildConfig/secret; access token is a secret — never hard-code. Incoming calls need a push token (FCM) registered, even in the foreground; dialing out does not.

## Related
- Repo: https://github.com/sendbird/sendbird-calls-android
