<!-- last-verified-against: sendbird-calls-android 1.12.5 -->
<!-- status: populated -->
# android calls

> Verified against the public mirror `sendbird/sendbird-calls-android` (README implementation guide, verified 2026-06-09). Compile NOT run in-repo (no Android/Java toolchain) — code quoted verbatim. 1.12.5 CHANGELOG reviewed 2026-09-28 — only local-recording pipeline fixes; none of the cited init/authenticate/listener/dial symbols changed. Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-calls-android

## Overview
Sendbird Calls adds voice/video calls. **Direct calls** are 1:1: dial a callee's user ID, their devices ring, accepting connects.

## Install (Gradle)
- `implementation 'com.sendbird.sdk:sendbird-calls:1.12.5'` (or `1.+`).

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
Register a push token via `SendBirdCall.registerPushToken(...)` for background calls. (source: sendbird-calls-android README §authenticate)

## Handle incoming calls
```java
SendBirdCall.addListener(UNIQUE_HANDLER_ID, new SendBirdCallListener() {
    @Override public void onRinging(DirectCall call) { /* incoming 1:1 call */ }
    @Override public void onInvitationReceived(RoomInvitation invitation) { /* incoming group-room invitation */ }
});
```
(source: sendbird-calls 1.12.4 — `SendBirdCallListener` has TWO required abstract methods, `onRinging(DirectCall)` + `onInvitationReceived(RoomInvitation)`, verified via javap of the published AAR 2026-06-22. `RoomInvitation` = `com.sendbird.calls.RoomInvitation`.)

## Make a call
```java
DialParams params = new DialParams(CALLEE_ID);
DirectCall call = SendBirdCall.dial(params, (directCall, e) -> {
    if (e == null) { /* dialing */ }
});
```
(source: sendbird-calls-android README §"make a call")

## Pitfalls
- Add the listener before expecting `onRinging`.
- App ID from BuildConfig/secret; access token is a secret — never hard-code. Background calls need a push token (FCM) registered.

## Related
- Repo: https://github.com/sendbird/sendbird-calls-android
