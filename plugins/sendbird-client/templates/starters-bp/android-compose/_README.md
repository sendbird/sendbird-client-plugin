<!-- status: populated -->
# Android Compose starter (best practice)

A small Jetpack Compose app (Kotlin, Gradle Kotlin DSL) with Sendbird Chat and the Compose-native
UIKit (`uikit-compose`) wired the recommended way: sign-in with a user ID, connect, the UIKit channel
list and conversation inside the app's `NavHost`, and sign-out. Start a new app from this folder,
then replace the user ID field with your own sign-in. The practices it follows are listed in
`../BEST_PRACTICES.md`.

## What is included

- `settings.gradle.kts` (Sendbird Maven repository), `app/build.gradle.kts` — `com.sendbird.sdk:uikit-compose:1.3.6` and `sendbird-chat:4.36.5`, navigation-compose, compile/target SDK 35, min SDK 24.
- `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt` — the one app-wide session (`StateFlow`): UIKit init, connect, session and connection handlers, sign-out.
- `.../auth/LoginService.kt` — `onLoginSucceeded(userId)` / `onLogout()` for your own sign-in.
- `.../MainActivity.kt` — sign-in and home screens, and a `NavHost` with `sendbirdGroupChannelNavGraph`.
- `.../sendbird/TokenProvider.kt`, `PushTokens.kt`, `SendbirdErrors.kt`, `StarterApplication.kt`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `app/src/main/java/com/example/starterbp/compose/StarterApplication.kt:9` | `SendbirdUikitCompose.init` once, in `Application.onCreate`; its `Flow` is collected (`app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:63`). |
| BP02 | `app/build.gradle.kts:11` | First non-blank of the Gradle property, the environment variable, and `local.properties`, passed on as `BuildConfig.SENDBIRD_APP_ID`; never fails the build (`gradle.properties:3`). Empty is reported on the sign-in screen (`app/src/main/java/com/example/starterbp/compose/MainActivity.kt:92`). |
| BP03 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:94` | Connects only after `onLoginSucceeded(userId)`; a sign-in that arrives before init finishes waits for it. |
| BP04 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:85` | `SendbirdChat.setSessionHandler` once after init, before any connect; it asks `TokenProvider` (`app/src/main/java/com/example/starterbp/compose/sendbird/TokenProvider.kt:5`) for a new token. |
| BP05 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:114` | `SendbirdUikitCompose.prepare(UikitCurrentUserInfo(...))`, then `connect()`. |
| BP06 | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:130` | The Channels button appears only after connect returns. |
| BP07 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:187` | A `ConnectionHandler` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:109` | Added before connect under one identifier, removed on sign-out (`app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:147`). |
| BP09 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:138` | Unregisters the push token (`app/src/main/java/com/example/starterbp/compose/sendbird/PushTokens.kt:28`), then `SendbirdUikitCompose.disconnect()`. |
| BP10 | `app/src/main/java/com/example/starterbp/compose/sendbird/PushTokens.kt:7` | One registration point for the FCM token, registered for the signed-in user after connect (`app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:135`). |
| BP11 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:64` | `UikitInitParams` becomes Chat SDK `InitParams` with caching on (read from `uikit-data` 1.3.6 bytecode, `UikitInitParamsKt.toInitParams`). |
| BP12 | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:51` | One `SendbirdTheme` around the app and the UIKit screens. |
| BP13 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdErrors.kt:9` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:125`). |
| BP16 | `app/src/main/java/com/example/starterbp/compose/sendbird/SendbirdSession.kt:37` | One `object`; `LoginService` (`app/src/main/java/com/example/starterbp/compose/auth/LoginService.kt:7`) forwards to it and the UI collects its state. |
| BP17 | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:106` | Test tags, exposed as resource ids (see below). |

Not applicable here: BP14 (SwiftUI), BP15 (React Native).

## Set the App ID

Pick one (first non-blank wins):

- `-PSENDBIRD_APP_ID=<your App ID>` on the Gradle command line, or `SENDBIRD_APP_ID=<your App ID>` in `gradle.properties`.
- The `SENDBIRD_APP_ID` environment variable.
- `SENDBIRD_APP_ID=<your App ID>` in `local.properties` (not committed).

Rebuild after changing it. The App ID is not a secret; session and access tokens are, and never go
into these files.

## Run

```bash
./gradlew :app:assembleDebug
./gradlew :app:installDebug   # with a device or emulator attached
```

Needs JDK 17 and the Android SDK (platform 35).

## Stable identifiers

The root sets `testTagsAsResourceId = true` (`app/src/main/java/com/example/starterbp/compose/MainActivity.kt:57`), so UI Automator and Appium see these test tags as resource ids.

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:106` |
| `sb_login_button` | Sign in button | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:108` |
| `sb_app_id_missing` | missing App ID message | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:96` |
| `sb_connection_status` | status text | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:129` |
| `sb_open_channels` | Channels button | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:133` |
| `sb_logout_button` | Sign out button | `app/src/main/java/com/example/starterbp/compose/MainActivity.kt:138` |
| `sb_channel_list`, `sb_message_input`, `sb_send_button` | not set | The UIKit screens come from `sendbirdGroupChannelNavGraph`, which takes no modifier for them. On the conversation screen the send button carries the content description "send message"; the message field is the text field at the bottom. |

## Verified

Checked on 2026-10-14 (JDK 17, Android SDK 35, emulator image API 35):

- `./gradlew :app:assembleDebug` through the plugin's e2e build check — passes.
- Deprecated SDK APIs (Kotlin warnings in app code) — none.
- Runtime, against a test application, with the App ID passed as a Gradle property: an
  instrumented test calls `LoginService().onLoginSucceeded(userId)` in the app's process right after
  launch, the server reports the user online, the Channels button opens the list, a channel opened
  by a second user appears and opens, the second user's message shows, a reply typed in the input
  and sent with the "send message" button reaches the server, and a later message from the second
  user appears without reopening the screen. No crash.
- By hand on the emulator: sign-in through the form, Connected, the channel list (with a back
  arrow to the home screen), then Sign out returns to the sign-in screen and the server reports the
  user offline. The test tags above showed up as resource ids in a UI Automator dump.
- Not exercised: push (no Firebase in the starter).

## Next steps

- Your sign-in: call `LoginService().onLoginSucceeded(userId)` on the main thread after it succeeds.
- Tokens: return a session token from your server in `sendbird/TokenProvider.kt`
  (`knowledge/curated/android/products/auth.md`).
- Push: add Firebase, then pass new FCM tokens to `PushTokens.onNewToken`, or register a
  `SendbirdPushHandler` after init and again after connect (`knowledge/curated/android/hosts/compose.md`,
  `knowledge/curated/android/cross-cutting/push.md`).
- Theme, fonts, strings: `knowledge/curated/android/cross-cutting/theme.md` ("Jetpack Compose host").
- Customizing the Compose UIKit: `knowledge/curated/android/hosts/compose.md`.

(source: knowledge/curated/android/hosts/compose.md)
(source: knowledge/curated/android/products/auth.md)
(source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html)
