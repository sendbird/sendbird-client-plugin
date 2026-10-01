<!-- status: populated -->
# templates/android/view/uikit

Sendbird UIKit on Android (View). Imports + calls copied verbatim from the public
`sendbird-uikit-android` sample (uikit-samples BaseApplication.kt, verified 2026-06-09).
NOT compiled in-repo (no Android/Java toolchain).

## Files
- `UIKitApplication.kt` — `SendbirdUIKit.init(adapter, this)` with app ID + user info.

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven`; `implementation("com.sendbird.sdk:uikit:3.26.2")`.
2. Set `UIKitApplication` as `android:name` in `AndroidManifest.xml`.
3. Launch UIKit fragments/activities after init (see the Android UIKit docs for the channel-list fragment).
4. App ID from BuildConfig/secret — never hard-code; access token is a secret.

## Variations (see knowledge/curated/android/products/uikit.md, all cited)
- Authenticated: return a token from `getAccessToken()`.
- Theme: `SendbirdUIKit.setDefaultThemeMode(...)`.
