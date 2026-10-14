<!-- status: populated -->
# Android View starter (best practice)

A small Android app (Kotlin, XML layouts, Gradle Kotlin DSL) with Sendbird Chat and the View-based
UIKit wired the recommended way: sign-in with a user ID, connect, the UIKit channel list and
conversation, and sign-out. Start a new app from this folder, then replace the user ID field with
your own sign-in. The practices it follows are listed in `../BEST_PRACTICES.md`.

## What is included

- `settings.gradle.kts` (Sendbird Maven repository), `app/build.gradle.kts` — `com.sendbird.sdk:uikit:3.26.3` and `sendbird-chat:4.36.5`, compile/target SDK 35, min SDK 24.
- `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt` — the one app-wide session (`StateFlow`): UIKit init, connect, session and connection handlers, sign-out.
- `.../auth/LoginService.kt` — `onLoginSucceeded(userId)` / `onLogout()` for your own sign-in.
- `.../MainActivity.kt` + `res/layout/activity_main.xml` — sign-in and home screens.
- `.../ChannelListActivity.kt` + `res/layout/activity_channel_list.xml` — hosts the UIKit `ChannelListFragment`; a row opens UIKit's conversation screen.
- `.../sendbird/TokenProvider.kt`, `PushTokens.kt`, `SendbirdErrors.kt`, `StarterApplication.kt`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `app/src/main/java/com/example/starterbp/view/StarterApplication.kt:9` | `SendbirdUIKit.init` once, in `Application.onCreate` (`app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:64`). |
| BP02 | `app/build.gradle.kts:9` | First non-blank of the Gradle property, the environment variable, and `local.properties`, passed on as `BuildConfig.SENDBIRD_APP_ID`; never fails the build (`gradle.properties:3`). Empty is reported on the sign-in screen (`app/src/main/java/com/example/starterbp/view/MainActivity.kt:28`). |
| BP03 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:104` | Connects only after `onLoginSucceeded(userId)`; a sign-in that arrives before init finishes waits for it. |
| BP04 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:95` | `SendbirdChat.setSessionHandler` once after init, before any connect; it asks `TokenProvider` (`app/src/main/java/com/example/starterbp/view/sendbird/TokenProvider.kt:5`) for a new token. |
| BP05 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:125` | Connects with `SendbirdUIKit.connect`; the adapter hands UIKit the signed-in user (`app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:68`). |
| BP06 | `app/src/main/java/com/example/starterbp/view/MainActivity.kt:68` | The Channels button appears only after connect returns. |
| BP07 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:198` | A `ConnectionHandler` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:119` | Added before connect under one identifier, removed on sign-out (`app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:160`). |
| BP09 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:149` | Unregisters the push token (`app/src/main/java/com/example/starterbp/view/sendbird/PushTokens.kt:28`), then `SendbirdUIKit.disconnect` in its completion. |
| BP10 | `app/src/main/java/com/example/starterbp/view/sendbird/PushTokens.kt:7` | One registration point for the FCM token, registered for the signed-in user after connect (`app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:145`). |
| BP11 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:69` | UIKit initializes the Chat SDK with local caching on. |
| BP12 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:64` | `SendbirdUIKit.setDefaultThemeMode` before init and before the first UIKit screen. |
| BP13 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdErrors.kt:8` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:135`). |
| BP16 | `app/src/main/java/com/example/starterbp/view/sendbird/SendbirdSession.kt:36` | One `object`; `LoginService` (`app/src/main/java/com/example/starterbp/view/auth/LoginService.kt:7`) forwards to it and `MainActivity` collects its state (`app/src/main/java/com/example/starterbp/view/MainActivity.kt:19`). |
| BP17 | `app/src/main/res/layout/activity_main.xml:2` | Resource ids (see below). |

Not applicable here: BP14 (SwiftUI), BP15 (React Native).

A trap this starter avoids: inside an object that implements `SendbirdUIKitAdapter`, a field named
`accessToken` resolves to the adapter's own `getAccessToken()`, which then calls itself. The
resulting stack overflow happens on a UIKit worker thread, so the connect callback never arrives and
nothing is logged. The field is named `sessionToken` instead.

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

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `app/src/main/res/layout/activity_main.xml:31` |
| `sb_login_button` | Sign in button | `app/src/main/res/layout/activity_main.xml:41` |
| `sb_app_id_missing` | missing App ID message | `app/src/main/res/layout/activity_main.xml:22` |
| `sb_connection_status` | status text | `app/src/main/res/layout/activity_main.xml:69` |
| `sb_open_channels` | Channels button | `app/src/main/res/layout/activity_main.xml:75` |
| `sb_logout_button` | Sign out button | `app/src/main/res/layout/activity_main.xml:83` |
| `sb_channel_list` | container of the UIKit channel list fragment | `app/src/main/res/layout/activity_channel_list.xml:4` |
| `sb_message_input`, `sb_send_button` | not set | UIKit's input layout already has ids: `etInputText` (message field) and `ibtnSend` (send button), in `res/layout/sb_view_message_input.xml` of `uikit-3.26.3.aar`. At runtime they appear under the app's package, for example `com.example.starterbp.view:id/ibtnSend`. |

## Verified

Checked on 2026-10-14 (JDK 17, Android SDK 35, emulator image API 35):

- `./gradlew :app:assembleDebug` through the plugin's e2e build check — passes.
- Deprecated SDK APIs (Kotlin and javac warnings in app code) — none.
- Runtime, against a test application, with the App ID passed as a Gradle property: an
  instrumented test calls `LoginService().onLoginSucceeded(userId)` in the app's process right after
  launch, the server reports the user online, the Channels button opens the list, a channel opened
  by a second user appears and opens, the second user's message shows, a reply typed in
  `etInputText` and sent with `ibtnSend` reaches the server, and a later message from the second user
  appears without reopening the screen. No crash.
- By hand on the emulator: sign-in through the form, Connected, the channel list, then Sign out
  returns to the sign-in screen and the server reports the user offline.
- Not exercised: push (no Firebase in the starter).

## Next steps

- Your sign-in: call `LoginService().onLoginSucceeded(userId)` on the main thread after it succeeds.
- Tokens: return a session token from your server in `sendbird/TokenProvider.kt`
  (`knowledge/curated/android/products/auth.md`).
- Push: add Firebase, then pass new FCM tokens to `PushTokens.onNewToken`, or switch to a
  `SendbirdPushHandler` (`knowledge/curated/android/cross-cutting/push.md`).
- Theme and strings: `knowledge/curated/android/cross-cutting/theme.md`.
- Customizing UIKit screens: `knowledge/curated/android/products/uikit.md`.

(source: knowledge/curated/android/products/uikit.md)
(source: knowledge/curated/android/products/auth.md)
(source: knowledge/curated/android/cross-cutting/theme.md)
(source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html)
