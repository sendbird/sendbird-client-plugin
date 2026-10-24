<!-- last-verified-against: n/a (conceptual host guidance) -->
<!-- status: populated -->
# android host — View

> Conceptual host guidance (no SDK API asserted). Verified 2026-06-10.

## Detection signals
- XML layouts (`res/layout`), `Activity`/`Fragment`, ViewBinding, `AppCompatActivity`, no Jetpack Compose dependency.

## Integration notes
- Sendbird UIKit / AI Agent are View/Fragment-based — the native fit. Enable `buildFeatures { viewBinding = true }`.
- `MessengerLauncher` / UIKit fragments need a `FragmentActivity` (see products/ai-agent.md, uikit.md).
- Init in `Application.onCreate`; add/remove channel handlers in the Activity/Fragment lifecycle (see cross-cutting/performance.md).
- Customizing UIKit screens (message views, input, channel list, header): see the "(View host)" sections in products/uikit.md; theme, fonts, and strings are in cross-cutting/theme.md.
- Screens of your own (Chat SDK without UIKit) in an app that targets API 35: on Android 15 the app is edge-to-edge and must handle insets itself, and the keyboard is the `WindowInsetsCompat.Type.ime()` inset. Pad every Activity's content by the system bar and keyboard insets right after `setContentView`, as `padForSystemBarsAndKeyboard()` in `templates/starters/android-view/.../SystemInsets.kt` does; without it a conversation screen's message input stays behind the keyboard and its header runs under the status bar. (source: https://developer.android.com/about/versions/15/behavior-changes-15, https://developer.android.com/develop/ui/views/layout/sw-keyboard — reviewed 2026-10-24)

## Related
- UIKit product: knowledge/curated/android/products/uikit.md
- Compose host: knowledge/curated/android/hosts/compose.md
