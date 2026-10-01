<!-- last-verified-against: uikit-compose 1.3.6 (UIKit for Jetpack Compose section); other notes are conceptual host guidance -->
<!-- status: populated -->
# android host — Compose

> Host guidance. The "UIKit for Jetpack Compose" section was checked with `javap` against the uikit-compose 1.3.6 AAR and compiled against it with chat 4.36.5; the other notes are conceptual. Verified 2026-09-30.

## Detection signals
- `androidx.compose.*` imports, `@Composable`, `setContent { }`, Compose BOM in Gradle.

## Integration notes
- The classic UIKit (`com.sendbird.sdk:uikit`) and AI Agent for Android are View/Fragment-based (see templates/android/compose/*/_README.md). UIKit also ships a Compose-native variant — see "UIKit for Jetpack Compose — init, then push" below.
- Host the View/Fragment screens via interop (`AndroidView`, `AndroidFragment`, `FragmentContainerView`), or start the provided activities (e.g. `MessengerActivity`).
- When you host those View/Fragment screens, init + session + connect are identical to the View host; the host only changes how UI is embedded. The Compose-native UIKit has its own init (below).

## UIKit for Jetpack Compose — init, then push

Sendbird ships a Compose-native UIKit: `implementation("com.sendbird.sdk:uikit-compose:1.3.6")` (same `https://repo.sendbird.com/public/maven` repository). Initialize it once in `Application.onCreate()` with `SendbirdUikitCompose.init(UikitInitParams(...))` — it returns a `Flow`, so collect it — and register the push handler after that call. When a user logs in, call `SendbirdUikitCompose.connect()` and register the handler again.

```kotlin
class BaseApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SendbirdUikitCompose.init(
            UikitInitParams(appId = APP_ID, context = this, isForeground = true)
        ).launchIn(MainScope())
        // Must be called after SendbirdUikitCompose.init
        SendbirdPushHelper.registerHandler(MyFirebaseMessagingService())
    }
}
```

(source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.SendbirdUikitCompose; https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/push-notifications; public sample sendbird-uikit-sample-android-jetpack-compose BaseApplication.kt)

## Related
- View host: knowledge/curated/android/hosts/view.md
- AI Agent: knowledge/curated/android/products/ai-agent.md
