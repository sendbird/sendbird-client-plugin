<!-- status: populated -->
# templates/android/compose/chat

`ChatViewModel.kt` — a `ViewModel` exposing a `StateFlow<ChatUiState>` plus a `ChatStatus`
composable, wrapping the verified Chat SDK calls. The SDK calls are identical to the verified
View-host template (`templates/android/view/chat/InitConnect.kt`); only the ViewModel/Compose
wrapper is new.

## Splice steps
1. Add the Chat SDK: `settings.gradle` maven `https://repo.sendbird.com/public/maven`,
   `build.gradle` `implementation("com.sendbird.sdk:sendbird-chat:4.+")`. Enable Compose
   (`buildFeatures { compose = true }`) + the Kotlin Compose compiler plugin.
2. Keep `SendbirdChat.init(...)` in your `Application` class (see the View-host template).
3. Copy `ChatViewModel.kt` into your app, adjust the package.
4. Drive it from a composable:
   ```kotlin
   @Composable
   fun ChatScreen(vm: ChatViewModel = viewModel()) {
       LaunchedEffect(Unit) { vm.connectUser("USER_ID") }
       ChatStatus(vm)
   }
   ```
5. App ID from `BuildConfig`/secret (do not hard-code). Authenticated apps connect with a token:
   `SendbirdChat.connect(userId, authToken) { ... }`.

## Notes
- Message UI: Chat SDK is headless. For prebuilt Compose chat screens use the Compose-native UIKit
  (`com.sendbird.sdk:uikit-compose`, see `templates/android/compose/uikit`).
- `StateFlow` + `collectAsState()` keeps Compose recomposition in sync with SDK callbacks.

## Compile status
`tools/templates/compile-check-android.sh` compiles this file (with the Compose compiler plugin and
Compose deps) together with the View templates, against both the pinned and the latest SDK set.
