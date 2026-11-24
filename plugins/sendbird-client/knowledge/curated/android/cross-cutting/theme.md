<!-- last-verified-against: sendbird-uikit-android 3.26.3; uikit-compose 1.3.6 -->
<!-- verified-at: 2026-11-23 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — theme (UIKit)

> Verified against sendbird.com/docs, the public `sendbird/sendbird-uikit-android` source and sample, and pinned/latest Android template compile on 2026-09-22. The runtime switch, fonts, strings, and Jetpack Compose sections were added on 2026-10-11: View host claims read from the public source on `main` (`UIKIT_VERSION = 3.26.3`), Compose claims from the `uikit-compose-1.3.6.aar` / `uikit-common-1.0.2.aar` with `javap`, and every Kotlin example compiled with `tools/curated/compile-snippets-android.sh` (verified 2026-10-11). The status bar section was added on 2026-10-12 from the same public source (`main`, commit `07ffe8e`) and compiled the same way. On 2026-11-23 the follow-system, color names, bubble color, icon, and default profile image sections were added, the Compose font example was corrected to include `bodySmall`, and the Compose colors, `SendbirdTheme`, and icon notes were added, from `main` (commit `04da94a`, `UIKIT_VERSION = 3.26.3`) and `uikit-compose-1.3.6.aar` / `uikit-common-1.0.2.aar`. Used by `/sendbird-client:ui-customize`. Do not invent API.

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

Restarting with `activity.intent` works for your own Activity that hosts UIKit fragments, which is what the sample restarts. UIKit's own Activities (`ChannelListActivity`, `ChannelActivity`, and the rest) store the theme in the intent when `newIntent(...)` creates it and read it from there first, so restarting one with its old intent brings back the old theme. Open them again with a new `newIntent(...)` after `setDefaultThemeMode`. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/activities/ChannelListActivity.java#L34-L36 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/activities/ChannelListActivity.java#L114-L117 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/activities/ChannelActivity.java#L196-L199)

## Follow the system dark mode (View host)
`ThemeMode` has only `Light` and `Dark`, and UIKit never reads the system's night mode. Read it yourself from `Configuration.uiMode` and pass the result to `setDefaultThemeMode`: at launch in `Application.onCreate`, and again in `Application.onConfigurationChanged`. When the system switches, Android recreates your Activity, and UIKit fragments built without a theme argument (`ChannelListFragment.Builder()`, `ChannelFragment.Builder(channelUrl)`) read the new mode when they are created again. Restored fragments are created inside `super.onCreate`, so in your host Activity call `setDefaultThemeMode` before `super.onCreate`. UIKit's own Activities keep the theme stored in their intent (see above), so they do not follow a system switch by themselves.

```kotlin
import android.app.Application
import android.content.res.Configuration
import com.sendbird.uikit.SendbirdUIKit

fun uikitThemeModeFor(configuration: Configuration): SendbirdUIKit.ThemeMode {
    val night = configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return if (night == Configuration.UI_MODE_NIGHT_YES) SendbirdUIKit.ThemeMode.Dark else SendbirdUIKit.ThemeMode.Light
}

class ThemedApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SendbirdUIKit.setDefaultThemeMode(uikitThemeModeFor(resources.configuration))
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        SendbirdUIKit.setDefaultThemeMode(uikitThemeModeFor(newConfig))
    }
}
```
This was read from the source and compiled, not run on a device. (source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L107-L115 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L331-L355 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/modules/ChannelListModule.java#L51-L53 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/AndroidManifest.xml#L34 ; https://developer.android.com/guide/topics/resources/runtime-changes)

## Custom colors (View host)
Declare UIKit's color resources with the same names in your app's `res/values/colors.xml`; app resources replace library resources of the same name. The primary ramp is `primary_500` (darkest) to `primary_100` (lightest), and the same goes for `secondary_*` and `error_*`. Light mode takes its accent (header buttons, outgoing bubbles, spinners) from `primary_main`, which is `primary_300`. Dark mode takes it from `primary_light`, which is `primary_200`, so set both to cover both modes. The other names are `background_700` to `background_50`, `onlight_01` to `onlight_04`, `ondark_01` to `ondark_04`, `overlay_01`, `overlay_02`, and `information`.

```xml
<!-- app/src/main/res/values/colors.xml -->
<resources>
    <color name="primary_500">#0B3D91</color>
    <color name="primary_400">#0D52BF</color>
    <color name="primary_300">#1A73E8</color> <!-- light mode accent -->
    <color name="primary_200">#8AB4F8</color> <!-- dark mode accent -->
    <color name="primary_100">#D2E3FC</color>
</resources>
```
(source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/colors.xml#L4-L74 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L111-L115 ; https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/color-resources ; https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/theme-resources)

## Message bubble colors (View host)
A text bubble is a shape tinted with a color selector, and UIKit ships four of them in `res/color`: `sb_message_me_tint_light` (outgoing, light: `primary_main`, pressed `primary_dark`), `sb_message_other_tint_light` (incoming, light: `background_100`), `sb_message_me_tint_dark` (outgoing, dark: `primary_light`), and `sb_message_other_tint_dark` (incoming, dark: `background_400`). User, file, voice, and multiple-file bubbles share them. To change only the bubble background everywhere, put files with the same names in your app's `res/color`. The text colors come from the `SendbirdBody3OnDark01` (outgoing) and `SendbirdBody3OnLight01` (incoming) styles, which other texts share too.

```xml
<!-- app/src/main/res/color/sb_message_me_tint_light.xml -->
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:state_pressed="true" android:color="@color/primary_dark" />
    <item android:color="#FF1A73E8" />
</selector>
```
For one screen only, pass `TextUIConfig` text colors to `ChannelFragment.Builder.setMessageTextUIConfig(fromMe, fromOthers)` and your own bubble drawables to `setMessageBackground(myBackground, otherBackground)`. Those drawables are not tinted, so they must carry their own color.

```kotlin
import android.graphics.Color
import com.sendbird.uikit.fragments.ChannelFragment
import com.sendbird.uikit.model.TextUIConfig

val fromMe = TextUIConfig.Builder().setTextColor(Color.WHITE).build()
val fromOthers = TextUIConfig.Builder().setTextColor(Color.BLACK).build()
val channelFragment = ChannelFragment.Builder(channelUrl)
    .setMessageTextUIConfig(fromMe, fromOthers)
    .build()
```
(source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/color/sb_message_me_tint_light.xml ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/color/sb_message_other_tint_light.xml ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/res/values/styles.xml#L853-L896 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/internal/ui/messages/MyUserMessageView.kt#L53-L56 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1893 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelFragment.java#L1966 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/model/TextUIConfig.kt#L266-L278)

## Icons and the default profile image (View host)
The docs say to replace an icon by overriding the drawable of the same name, such as `icon_send`, `icon_add`, `icon_arrow_left`, `icon_more`, or `icon_user`. UIKit ships these icons as PNGs in the density folders (`drawable-mdpi` to `drawable-xxxhdpi`) only, and Android picks the closest density first, so a file in your plain `res/drawable/` does not replace them. Put a vector in `res/drawable-anydpi/`, which matches every density, or PNGs in the same density folders. Thirteen direction icons (`icon_arrow_left`, `icon_send`, `icon_chevron_right`, `icon_reply`, and others) also have right-to-left versions in `drawable-ldrtl-` density folders for right-to-left layouts; add `res/drawable-ldrtl-anydpi/` copies for those, or UIKit's RTL icon still wins. UIKit tints most icons, so a colored image is drawn in one color.

A user without a profile picture is drawn as `icon_user`, tinted, on a `background_300` circle. Replacing `icon_user` changes that silhouette; there is no setting for a full-color placeholder. For one, give users a profile URL or draw the avatar in a custom message view (knowledge/curated/android/products/uikit.md, "Custom message views, including file messages (View host)").

<!-- compile: skip -->
```text
app/src/main/res/drawable-anydpi/icon_send.xml        your vector
app/src/main/res/drawable-ldrtl-anydpi/icon_send.xml  the same icon, mirrored for RTL
app/src/main/res/drawable-anydpi/icon_user.xml        default profile image (one color; UIKit tints it)
```
(source: https://sendbird.com/docs/chat/uikit/v3/android-view/customizations/resource-customization/icon-resources ; https://github.com/sendbird/sendbird-uikit-android/tree/main/uikit/src/main/res ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/utils/ViewUtils.java#L337-L343 ; https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/utils/DrawableUtils.java#L99-L106 ; https://developer.android.com/topic/architecture/views/resources/providing-resources-views)

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

fun appTypography(font: FontFamily = FontFamily.Serif): Typography {
    val base = sendbirdTypography()
    return sendbirdTypography(
        displayLarge = base.displayLarge.copy(fontFamily = font),
        displayMedium = base.displayMedium.copy(fontFamily = font),
        displaySmall = base.displaySmall.copy(fontFamily = font),
        headlineLarge = base.headlineLarge.copy(fontFamily = font),
        headlineMedium = base.headlineMedium.copy(fontFamily = font),
        headlineSmall = base.headlineSmall.copy(fontFamily = font),
        titleLarge = base.titleLarge.copy(fontFamily = font),
        titleMedium = base.titleMedium.copy(fontFamily = font),
        titleSmall = base.titleSmall.copy(fontFamily = font),
        bodyLarge = base.bodyLarge.copy(fontFamily = font),
        bodyMedium = base.bodyMedium.copy(fontFamily = font),
        bodySmall = base.bodySmall.copy(fontFamily = font),   // message text
        labelLarge = base.labelLarge.copy(fontFamily = font),
        labelMedium = base.labelMedium.copy(fontFamily = font),
        labelSmall = base.labelSmall.copy(fontFamily = font),
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

Message text uses `bodySmall`, so a font change that leaves out `bodySmall` does not reach the bubbles; the example above sets the font on every style. UIKit also reads `labelMedium`, `labelSmall`, `headlineMedium`, `bodyMedium`, `titleSmall`, `bodyLarge`, `titleMedium`, `headlineSmall`, `titleLarge`, and `labelLarge`. The default font is Roboto. For your own font, pass `FontFamily(Font(R.font.your_font))`. (source: uikit-compose-1.3.6.aar javap -c com.sendbird.uikit.compose.channels.group.detail.MessageItemKt — the default text style of the text message items is `bodySmall`) (source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.theme.SendbirdFontFamily)

Wrap UIKit screens in `SendbirdTheme`, not in your own `MaterialTheme`. `SendbirdTheme` also sets an internal dark-mode flag that UIKit composables read (other users' bubbles, top bars, text fields, buttons). The docs also show passing your app's own Material theme to the `theme` parameter; with a plain `MaterialTheme` there the flag stays off, so those parts keep their light colors in dark mode. Pass your own color schemes to `SendbirdTheme` instead. `isDynamicColor = true` uses Material You colors on Android 12 (API 31) and later; it is off by default. (source: uikit-compose-1.3.6.aar javap -c com.sendbird.uikit.compose.theme.ThemesKt — `SendbirdTheme` is the only caller that sets the flag) (source: uikit-compose-1.3.6.aar javap -c com.sendbird.uikit.compose.SendbirdUikitCompose) (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/themes)

### Colors and message bubbles (Compose)
`sendbirdLightColorScheme(...)` and `sendbirdDarkColorScheme(...)` take every Material 3 color slot, each with a default. The ones UIKit uses for messages: `primary` is the outgoing bubble (and buttons and other accents); `surfaceBright` is the incoming bubble in light mode and `surfaceContainerHighest` in dark mode; `background` at 80% opacity is the outgoing text and `onBackground` the incoming text. By default `primary` is UIKit's primary main color in light mode and its primary light color in dark mode.

```kotlin
import androidx.compose.material3.ColorScheme
import androidx.compose.ui.graphics.Color
import com.sendbird.uikit.compose.theme.sendbirdDarkColorScheme
import com.sendbird.uikit.compose.theme.sendbirdLightColorScheme

val BrandLightColors: ColorScheme = sendbirdLightColorScheme(
    primary = Color(0xFF1A73E8),             // outgoing bubbles, buttons
    surfaceBright = Color(0xFFF1F3F4),       // incoming bubbles (light)
)
val BrandDarkColors: ColorScheme = sendbirdDarkColorScheme(
    primary = Color(0xFF8AB4F8),             // outgoing bubbles (dark)
    surfaceContainerHighest = Color(0xFF3C4043), // incoming bubbles (dark)
)
```
Pass them to `SendbirdTheme` as `lightColorScheme` and `darkColorScheme`. To change the outgoing text bubble without touching `primary`, draw it through the channel screen's `messageItem` slot with `MessageItemFactory(myTextMessageItem = { MyTextMessageItem(message = it, textBackgroundColor = ..., textColor = ...) })`; rows drawn that way use the factory's default emoji reaction handlers. (source: uikit-compose-1.3.6.aar javap -l com.sendbird.uikit.compose.theme.ThemesKt — color slot parameters) (source: uikit-compose-1.3.6.aar javap -c -l com.sendbird.uikit.compose.channels.group.detail.MessageItemKt — bubble defaults) (source: uikit-compose-1.3.6.aar javap -l com.sendbird.uikit.compose.channels.group.detail.ChannelScreenKt) (source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/customization)

### Icons, the default profile image, dates, and RTL (Compose)
- **Icons**: the Compose UIKit takes its icons from `uikit-common` as PNGs in density folders, so a drawable with the same name in your app replaces one, following the same density and `drawable-anydpi` rule as the View host. Keep `icon_user`, `icon_broadcast`, `icon_file_document`, `icon_gif`, `icon_photo`, and `icon_play` as PNG or WebP: UIKit loads them as bitmaps, and a vector under those names was not tested.
- **Default profile image**: `icon_user`, tinted, on a `surfaceContainerHigh` circle. For your own avatar, draw the other user's row yourself with `OtherMessageItem` and its `profile` slot inside the message item factory.
- **Dates**: formatted with the platform's date utilities and the device locale, as on the View host; there is no pattern setting. `MyMessageItem` and `OtherMessageItem` have a `sentAt` slot for your own time view.
- **RTL**: the Compose UIKit has no RTL code and ships no mirrored icons; your app's `android:supportsRtl` decides the layout direction. How its layouts behave in RTL was not tested.

(source: uikit-common-1.0.2.aar res/drawable-*-v4) (source: uikit-compose-1.3.6.aar javap -c com.sendbird.uikit.compose.channels.group.detail.MessageItemKt$OtherMessageItem$2 — `icon_user` placeholder) (source: uikit-compose-1.3.6.aar javap -l com.sendbird.uikit.compose.channels.group.detail.MessageItemKt — `MyMessageItem`, `OtherMessageItem`, `sentAt`, `profile`) (source: uikit-common-1.0.2.aar javap com.sendbird.uikit.core.common.extension.DateExtensionsKt) (source: https://developer.android.com/guide/topics/manifest/application-element)

## Pitfalls
- Set the theme mode before presenting fragments/activities; a screen already showing keeps its theme until it is recreated.
- UIKit's own Activities keep the theme stored in their intent; restart them with a new `newIntent(...)`, not the old intent.
- Dark mode accent is `primary_light` (`primary_200`), not `primary_main`.
- Icons in plain `res/drawable/` do not replace UIKit's density PNGs; use `drawable-anydpi`, plus `drawable-ldrtl-anydpi` for direction icons.
- Compose: wrap UIKit screens in `SendbirdTheme`, and include `bodySmall` when you change the font.
- Overriding a `Sendbird*` style or `sb_text_*` string replaces it everywhere UIKit uses it.

## Related
- UIKit: knowledge/curated/android/products/uikit.md
- Compose host: knowledge/curated/android/hosts/compose.md
