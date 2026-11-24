<!-- status: populated -->
# templates/android/view/uikit

Sendbird UIKit on Android (View). Imports + calls copied verbatim from the public
`sendbird-uikit-android` sample (uikit-samples BaseApplication.kt, verified 2026-06-09).
NOT compiled in-repo (no Android/Java toolchain).

## Files
- `UIKitApplication.kt` — `SendbirdUIKit.init(adapter, this)` with app ID + user info.
- `ThemedUIKit.kt` — dark mode that follows the system: `uikitThemeModeFor(...)`, an `Application` that sets the mode at launch and on configuration changes, and a host Activity for UIKit fragments that sets it before `super.onCreate`.
- `res/values/sendbird_brand.xml`, `res/color/sb_message_*_tint_*.xml` — brand palette (`primary_100` to `primary_500`), the message text font (`SendbirdBody3OnDark01`, `SendbirdBody3OnLight01`), outgoing text color, and the four bubble background selectors. Copy them into the app's `res/` with the same names.

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven`; `implementation("com.sendbird.sdk:uikit:3.26.2")`.
2. Set `UIKitApplication` as `android:name` in `AndroidManifest.xml`.
3. Launch UIKit fragments/activities after init (see the Android UIKit docs for the channel-list fragment).
4. App ID from BuildConfig/secret — never hard-code; access token is a secret.

## Variations (see knowledge/curated/android/products/uikit.md, all cited)
- Authenticated: return a token from `getAccessToken()`.
- Theme: `SendbirdUIKit.setDefaultThemeMode(...)`.

## Theme (dark mode, brand colors, font, bubble colors)
Use these files when the request is to restyle the UIKit screens. Keep only the parts the request asks for and take the values from the app. Register the `Application` in the manifest. UIKit's own Activities keep the theme from their intent, so only fragments hosted in your own Activity follow a system switch while open. The dark-mode outgoing text color is in `Widget.Sendbird.Dark.Message.Me.User`; redefine it the same way if needed. The Kotlin compiles in `compile-check-android.sh`; the `res/` files were linked against UIKit 3.26.3 once and are not built by that script. Details and sources: knowledge/curated/android/cross-cutting/theme.md.
