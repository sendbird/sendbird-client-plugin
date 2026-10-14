<!-- last-verified-against: sendbird-uikit-android 3.26.3; uikit-compose 1.3.6 -->
<!-- verified-at: 2026-10-12 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — theme (UIKit)

> Verified against sendbird.com/docs, the public `sendbird/sendbird-uikit-android` source and sample, and pinned/latest Android template compile on 2026-09-22. The runtime switch, fonts, strings, and Jetpack Compose sections were added on 2026-10-11: View host claims read from the public source on `main` (`UIKIT_VERSION = 3.26.3`), Compose claims from the `uikit-compose-1.3.6.aar` / `uikit-common-1.0.2.aar` with `javap`, and every Kotlin example compiled with `tools/curated/compile-snippets-android.sh` (verified 2026-10-11). The status bar section was added on 2026-10-12 from the same public source (`main`, commit `07ffe8e`) and compiled the same way. Used by `/sendbird-client:ui-customize`. Do not invent API.

## Light / dark (View host)
```kotlin
SendbirdUIKit.setDefaultThemeMode(SendbirdUIKit.ThemeMode.Light)   // or .Dark
```
Set before launching UIKit screens (typically in the `Application`/init). (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/theme-resources) (source: sendbird/sendbird-uikit-android sample BaseApplication.kt)

One screen in a different mode: `ChannelFragment.Builder(channelUrl, SendbirdUIKit.ThemeMode.Dark)`, or `Builder(channelUrl, R.style.YourTheme)` for a custom theme resource. (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1190)

## Switching light / dark at runtime (View host)
`setDefaultThemeMode` only stores the mode in a static field (`SendbirdUIKit.java` line 1015); screens read it when they are created, so a screen that is already showing keeps its old theme. The UIKit sample app switches by setting the mode and then restarting the current Activity:

```kotlin
fun switchUikitTheme(activity: Activity, dark: Boolean) {
    SendbirdUIKit.setDefaultThemeMode(if (dark) SendbirdUIKit.ThemeMode.Dark else SendbirdUIKit.ThemeMode.Light)
    activity.finish()
    activity.startActivity(activity.intent)
}
```
Persist the choice yourself (the sample keeps it in its own preferences) and call `setDefaultThemeMode` with it on the next launch before any UIKit screen opens. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/theme-resources) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L1015) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit-samples/src/main/java/com/sendbird/uikit/samples/common/SampleSettingsFragment.kt#L423)

## Custom colors (View host)
Override the UIKit theme resources (colors) via your app's resource overrides / the documented theme attributes. See the Android UIKit themes guide for the resource names. (source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/color-resources)

## Fonts (View host)
- **Everywhere:** every UIKit text uses a `Sendbird*` TextAppearance style (171 of them in `res/values/sendbird_text_appearance.xml`, for example `SendbirdBody3OnLight01`). Declaring a style with the same name in your app replaces UIKit's, because app resources take priority over library resources. The replacement is the whole style, so copy its other items (size, color) along with the new `android:fontFamily`.

```xml
<!-- app/src/main/res/values/styles.xml -->
<style name="SendbirdBody3OnLight01">
    <item name="android:fontFamily">@font/your_font</item>
    <item name="android:textStyle">normal</item>
    <item name="android:textSize">14sp</item>
    <item name="android:lineSpacingExtra">6sp</item>
    <item name="android:textColor">@color/onlight_text_high_emphasis</item>
</style>
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/text-appearance-resources) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/res/values/sendbird_text_appearance.xml#L920) (source: https://developer.android.com/studio/write/add-resources)

- **One screen's messages and input:** `TextUIConfig.Builder().setCustomFontRes(R.font.your_font)` (or `setFamilyName("...")`), applied with `ChannelFragment.Builder.setMessageTextUIConfig(fromMe, fromOthers)` and `setMessageInputTextUIConfig(config)`:

```kotlin
import com.sendbird.uikit.fragments.ChannelFragment
import com.sendbird.uikit.model.TextUIConfig

val font = TextUIConfig.Builder().setFamilyName("serif").build() // or .setCustomFontRes(R.font.your_font)
val fragment = ChannelFragment.Builder(channelUrl)
    .setMessageTextUIConfig(font, font)
    .setMessageInputTextUIConfig(font)
    .build()
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/chat-customization/message-item-ui) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/model/TextUIConfig.kt#L318) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1893)

## Status bar color (View host)
UIKit's own Activities (all 27 Activity classes in `com.sendbird.uikit.activities`) apply a theme themselves in `onCreate`: the theme id in the intent or, by default, the one for `SendbirdUIKit.getDefaultThemeMode()`, which is `AppTheme.Sendbird` for Light and `AppTheme.Dark.Sendbird` for Dark (`SendbirdUIKit.java` lines 111 and 115, `ChannelListActivity.java` line 117). Each of them then calls the internal `setInsetMarginAndStatusBarColor(...)` (`ViewExtensions.kt` line 158). So the status bar on UIKit screens is set by UIKit, not by your app theme:

- **Edge-to-edge** (apps that target API 35 are edge-to-edge on Android 15 devices, and there `Window.setStatusBarColor` and `android:statusBarColor` have no effect): call `SendbirdUIKit.setEdgeToEdgeConfig(EdgeToEdgeConfig(...))` (UIKit 3.23.0+) before opening UIKit screens. When the config has a color for the current mode (`statusBarColorLight` or `statusBarColorDark`), UIKit adds a view of that color behind the status bar. `useAppearanceLightStatusBars` (3.23.3+) picks the status bar icon appearance; when it is `null`, UIKit uses the light appearance (dark icons) in Light mode and the dark appearance in Dark mode.

```kotlin
import android.graphics.Color
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.model.EdgeToEdgeConfig

SendbirdUIKit.setEdgeToEdgeConfig(
    EdgeToEdgeConfig(
        statusBarColorLight = Color.parseColor("#FF742DDD"),
        statusBarColorDark = Color.BLACK,
        useAppearanceLightStatusBars = false, // white icons on the purple bar in Light mode
    )
)
```

- **Not edge-to-edge:** the platform Material theme sets `android:statusBarColor` to `?attr/colorPrimaryDark`, and UIKit's `AppTheme` sets `colorPrimaryDark` to `@color/primary_extra_dark` (`AppTheme.Dark` uses `@color/background_500`). `EdgeToEdgeConfig` is UIKit's only status bar setting. In an Activity of your own that hosts a UIKit fragment, the status bar follows that Activity's theme, so set `colorPrimaryDark` there, as the staff answer in the case below says.

(source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L832) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/model/EdgeToEdgeConfig.kt#L10) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/internal/extensions/ViewExtensions.kt#L158-L208) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/activities/ChannelListActivity.java#L114-L122) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L111) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/styles.xml#L3-L7) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/styles_dark.xml#L3-L7) (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/CHANGELOG.md — v3.23.0) (source: https://developer.android.com/about/versions/15/behavior-changes-15#edge-to-edge) (source: https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/res/res/values/themes_material.xml)
- **Cases:** https://github.com/sendbird/sendbird-uikit-android/discussions/27 (staff answer written before UIKit 3.23.0)

## Message input colors (View host)
Each screen (module) points each of its components to a style, and a component style is the smallest unit you can restyle. The channel screen's `Module.Channel` points `sb_component_channel_message_input` to `Component.ChannelMessageInput`, which holds the input's attributes, such as `sb_message_input_background`, `sb_message_input_text_background`, `sb_message_input_text_appearance`, and the button icons and tints. To change only the input, create a style that inherits `Component.ChannelMessageInput`, then redefine `Module.Channel` in your app's `styles.xml` with all four of its component items, pointing the input item at your style. The dark theme uses `Module.Dark.Channel` and `Component.Dark.ChannelMessageInput` the same way.

<!-- compile: skip -->
```xml
<style name="Component.ChannelMessageInput.Brand" parent="Component.ChannelMessageInput">
    <item name="sb_message_input_background">@color/brand_input_background</item>
</style>
<style name="Module.Channel">
    <item name="sb_component_header">@style/Component.Header.Channel</item>
    <item name="sb_component_list">@style/Component.List.Channel</item>
    <item name="sb_component_channel_message_input">@style/Component.ChannelMessageInput.Brand</item>
    <item name="sb_component_status">@style/Component.Status.Channel</item>
</style>
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/style-resources) (source: https://sendbird.com/docs/chat/uikit/v3/android-view/tutorial/customize-channel-settings — redefines `Module.ChannelSettings` the same way) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/res/values/styles.xml#L65-L70 — `Module.Channel`; `Component.ChannelMessageInput` at lines 286-300) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/res/values/styles_dark.xml#L66-L71)

## Dates and times (View host)
UIKit formats message times and date separators with the platform's `android.text.format.DateUtils.formatDateTime(...)` and date flags, not with a format pattern. The device's locale therefore decides the language, such as Korean month names, and the order of the parts, and UIKit's public API has no setter for a date or time pattern. The one word UIKit supplies itself is "Yesterday", the string resource `sb_text_yesterday`. To show a different format, draw the time yourself in a custom message view (see "Custom message views, including file messages" in knowledge/curated/android/products/uikit.md). (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/java/com/sendbird/uikit/utils/DateUtils.java#L25-L92) (source: uikit 3.26.3 AAR, `javap` — the only date class is `com.sendbird.uikit.utils.DateUtils`, with no format setter) (source: https://developer.android.com/reference/android/text/format/DateUtils#formatDateTime(android.content.Context,%20long,%20int))

## Strings and localization (View and Compose hosts)
UIKit's texts are Android string resources named `sb_text_*` (headers, input hint, menu items, error and "toast" messages). The View UIKit keeps them in `uikit/src/main/res/values/strings.xml`; the Compose UIKit gets them from `uikit-common-1.0.2.aar` (`res/values/values.xml`, 239 strings). Both ship only the default `values` folder (no translated folders), so:

- Change a text: declare the same name in your app's `res/values/strings.xml`.
- Translate: add the same names to `res/values-<language>/strings.xml`. Android picks the folder that matches the device locale.

```xml
<!-- app/src/main/res/values-es/strings.xml -->
<resources>
    <string name="sb_text_channel_input_text_hint">Escribe un mensaje</string>
    <string name="sb_text_toast_success_copy">Copiado</string>
</resources>
```

- Compose "toast" messages are Snackbars whose text comes from these resources: after "Copy" in the message menu, `DefaultMessageMenuDialogContract` shows `context.getString(R.string.sb_text_toast_success_copy)`, and the download items use `sb_text_toast_success_start_download_file` / `sb_text_toast_success_download_file`, so the same overrides apply.
- Format arguments must stay in place (for example `sb_text_channel_typing_indicator_single` is `%s is typing…`).
- The "new message" tooltip in the Compose channel screen (`MessageTooltip`) reads `sb_text_channel_tooltip_singular` (`1 new message`) for one message and `sb_text_channel_tooltip_with_count` (`%d new messages`) for more, so override both, and keep `%d` in the second. (source: uikit-common-1.0.2.aar `res/values/values.xml` lines 70-71) (source: uikit-compose-1.3.6.aar `javap -c com.sendbird.uikit.compose.component.ButtonKt` — `MessageTooltip` loads both resources with `stringResource`)

(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/string-resources) (source: https://github.com/sendbird/sendbird-uikit-android/blob/07ffe8efc97e2d71dedc466ad868df817e5f433e/uikit/src/main/res/values/strings.xml) (source: uikit-common-1.0.2.aar res/values/values.xml) (source: uikit-compose-1.3.6.aar javap -c com.sendbird.uikit.compose.channels.group.detail.DefaultMessageMenuDialogContract) (source: https://developer.android.com/studio/write/add-resources)

## Jetpack Compose host
The Compose UIKit draws everything through `MaterialTheme` and wraps its screens in `SendbirdTheme(lightColorScheme, darkColorScheme, shapes, typography, isDarkTheme, isDynamicColor, content)`. `isDarkTheme` follows the system setting by default; pass your own value to force a mode or to switch at runtime (the theme recomposes when the value changes). Apply it to every UIKit screen through the `theme` parameter of `sendbirdGroupChannelNavGraph`. For fonts, start from `sendbirdTypography()` and copy the styles you change, because a `TextStyle` you pass replaces the default style for that slot.

```kotlin
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.font.FontFamily
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import com.sendbird.uikit.compose.navigation.SendbirdNavigation
import com.sendbird.uikit.compose.navigation.sendbirdGroupChannelNavGraph
import com.sendbird.uikit.compose.theme.SendbirdTheme
import com.sendbird.uikit.compose.theme.sendbirdTypography

fun appTypography(): Typography {
    val base = sendbirdTypography()
    return sendbirdTypography(
        bodyLarge = base.bodyLarge.copy(fontFamily = FontFamily.Serif),
        bodyMedium = base.bodyMedium.copy(fontFamily = FontFamily.Serif),
        titleMedium = base.titleMedium.copy(fontFamily = FontFamily.Serif),
    )
}

@Composable
fun SendbirdScreens(navController: NavHostController, isDark: Boolean) {
    NavHost(navController = navController, startDestination = SendbirdNavigation.GroupChannel.route) {
        sendbirdGroupChannelNavGraph(
            navController = navController,
            theme = { content ->
                SendbirdTheme(isDarkTheme = isDark, typography = appTypography()) { content() }
            }
        )
    }
}
```
Custom colors go through `sendbirdLightColorScheme(...)` / `sendbirdDarkColorScheme(...)` passed as `lightColorScheme` / `darkColorScheme`. Strings: see "Strings and localization" above. (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/themes) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.theme.ThemesKt, com.sendbird.uikit.compose.theme.TypographyKt, com.sendbird.uikit.compose.navigation.NavigationKt)

## Pitfalls
- Set the theme mode before presenting fragments/activities; a screen already showing keeps its theme until it is recreated.
- Overriding a `Sendbird*` style or `sb_text_*` string replaces it everywhere UIKit uses it.

## Related
- UIKit: knowledge/curated/android/products/uikit.md
- Compose host: knowledge/curated/android/hosts/compose.md
- AI Agent theme: knowledge/curated/android/cross-cutting/ai-agent-theme.md
