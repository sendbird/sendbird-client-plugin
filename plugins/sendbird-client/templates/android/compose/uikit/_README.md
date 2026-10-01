<!-- status: populated -->
# templates/android/compose/uikit

Compose-native Sendbird UIKit: `com.sendbird.sdk:uikit-compose` (a separate artifact from the
View/Fragment-based `com.sendbird.sdk:uikit`). Symbols verified with `javap` against the published
uikit-compose 1.3.6 AAR and its uikit-data 1.3.6 dependency; call shapes from the public sample
`sendbird-uikit-sample-android-jetpack-compose` and the Jetpack Compose UIKit docs (navigation,
authentication), verified 2026-09-30. Compiled by `tools/templates/compile-check-android.sh`.

## Files
- `UikitComposeApplication.kt` — `SendbirdUikitCompose.init(UikitInitParams(...))` in `Application.onCreate()`; init returns a `Flow<UikitInitResult>` that must be collected.
- `UikitComposeApp.kt` — `UikitComposeActivity` + `SendbirdChatApp(userId)`: `prepare(UikitCurrentUserInfo(...))`, `connect()`, and a `NavHost` hosting `sendbirdGroupChannelNavGraph(navController)` inside `SendbirdTheme`.

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven` in `settings.gradle.kts`;
   `implementation("com.sendbird.sdk:uikit-compose:1.3.6")` in the module `build.gradle.kts`.
   Enable Compose (`buildFeatures { compose = true }` + the Kotlin Compose compiler plugin). The
   templates also use `androidx.activity:activity-compose` (`setContent`) and
   `androidx.navigation:navigation-compose` (`NavHost`).
2. Copy `UikitComposeApplication.kt`, adjust the package, and register it in `AndroidManifest.xml`
   (`android:name=".UikitComposeApplication"`).
3. Copy `UikitComposeApp.kt`. Either launch `UikitComposeActivity`, or call `SendbirdChatApp(userId)`
   from your own `setContent { SendbirdTheme { ... } }`.
4. Already have a `NavHost`? Add `sendbirdGroupChannelNavGraph(navController)` to it and navigate to
   `SendbirdNavigation.GroupChannel.route` (or `navController.navigateToChannels()`).
5. App ID from BuildConfig/secret — never hard-code. Authenticated apps pass the token:
   `UikitCurrentUserInfo(userId = userId, authToken = token)`.

## Notes
- Push: register your `SendbirdPushHandler` after `init` and again after `connect()` on login
  (`knowledge/curated/android/hosts/compose.md`, `templates/android/view/chat/PushRegistration.kt`).
- Deep link to one channel: `navController.navigateToChannel(channelUrl)` (see `openSendbirdChannel`).
- Logout: `SendbirdUikitCompose.disconnect()` (suspend) after unregistering the push handler.
- Already on the View-based UIKit (`com.sendbird.sdk:uikit`)? It keeps its own init
  (`templates/android/view/uikit/UIKitApplication.kt`); from Compose, start its activities or host its
  fragments via interop.
