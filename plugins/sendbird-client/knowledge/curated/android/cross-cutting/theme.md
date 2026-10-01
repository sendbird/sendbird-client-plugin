<!-- last-verified-against: sendbird-uikit-android 3.26.3 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — theme (UIKit)

> Verified against sendbird.com/docs, the public `sendbird/sendbird-uikit-android` sample, and pinned/latest Android template compile on 2026-09-22. Used by `/sendbird-client:ui-customize`. Do not invent API.

## Light / dark
```kotlin
SendbirdUIKit.setDefaultThemeMode(SendbirdUIKit.ThemeMode.Light)   // or .Dark
```
Set before launching UIKit screens (typically in the `Application`/init). (source: sendbird.com/docs UIKit v3 android themes overview; sendbird/sendbird-uikit-android sample BaseApplication.kt)

## Custom colors / fonts
Override the UIKit theme resources (colors, fonts) via your app's resource overrides / the documented theme attributes. See the Android UIKit themes guide for the resource names. (source: sendbird.com/docs UIKit v3 android themes)

## Pitfalls
- Set the theme mode before presenting fragments/activities.
- Apply changes explicitly when the user toggles theme.

## Related
- UIKit: knowledge/curated/android/products/uikit.md
- AI Agent theme: knowledge/curated/android/cross-cutting/ai-agent-theme.md
