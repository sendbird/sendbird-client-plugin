<!-- status: populated -->
# templates/android/view/calls

Sendbird Calls (voice/video) on Android. Code from the public `sendbird-calls-android`
README (verified 2026-06-09); every import path verified via org-wide code search of
public Sendbird repos. NOT compiled in-repo (no Android/Java toolchain).

## Files
- `SetupCalls.java` — `init` / `authenticate` / `addIncomingCallListener` / `dial`.

## How to splice
1. Gradle: `implementation 'com.sendbird.sdk:sendbird-calls:1.12.4'`.
2. `SetupCalls.init(context, appId)` at launch, then `authenticate(...)`.
3. Add a `SendBirdCallListener` for incoming calls; register a push token (FCM) for background.
4. App ID from BuildConfig/secret — never hard-code; access token is a secret.

## Variations (see knowledge/curated/android/products/calls.md, all cited)
- Video call: configure via `CallOptions` on `DialParams`.
