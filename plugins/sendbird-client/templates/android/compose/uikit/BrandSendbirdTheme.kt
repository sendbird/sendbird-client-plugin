// source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/themes (SendbirdTheme, sendbirdTypography, color schemes)
// source: uikit-compose-1.3.6.aar javap com.sendbird.uikit.compose.theme.ThemesKt (SendbirdTheme sets the internal dark flag)
// source: uikit-compose-1.3.6.aar javap -c -l com.sendbird.uikit.compose.channels.group.detail.MessageItemKt
//   (outgoing bubble = primary; incoming = surfaceBright, or surfaceContainerHighest in dark; message text = bodySmall)
// Compiled with tools/templates/compile-check-android.sh against uikit-compose 1.3.6.
// Guide: knowledge/curated/android/cross-cutting/theme.md ("Jetpack Compose host", "Colors and message bubbles (Compose)").
//
// Dark mode that follows the system, brand colors, a custom font in every text style, and bubble
// colors. Wrap UIKit screens in SendbirdTheme, not a plain MaterialTheme.
package com.sendbird.client.templatecheck.compose.uikit

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import com.sendbird.uikit.compose.channels.group.detail.ChannelScreen
import com.sendbird.uikit.compose.channels.group.detail.MessageItemFactory
import com.sendbird.uikit.compose.channels.group.detail.MyTextMessageItem
import com.sendbird.uikit.compose.navigation.SendbirdNavigation
import com.sendbird.uikit.compose.navigation.sendbirdGroupChannelNavGraph
import com.sendbird.uikit.compose.theme.SendbirdTheme
import com.sendbird.uikit.compose.theme.sendbirdDarkColorScheme
import com.sendbird.uikit.compose.theme.sendbirdLightColorScheme
import com.sendbird.uikit.compose.theme.sendbirdTypography

private val BrandPrimary = Color(0xFF1A73E8)
private val BrandPrimaryDark = Color(0xFF8AB4F8)

/** Light colors: primary also colors buttons and accents, not only outgoing bubbles. */
val BrandLightColors: ColorScheme = sendbirdLightColorScheme(
    primary = BrandPrimary,             // outgoing text and file bubbles
    surfaceBright = Color(0xFFF1F3F4),  // incoming bubbles (light)
)

val BrandDarkColors: ColorScheme = sendbirdDarkColorScheme(
    primary = BrandPrimaryDark,                   // outgoing bubbles (dark)
    surfaceContainerHighest = Color(0xFF3C4043),  // incoming bubbles (dark)
)

/** Every slot gets the font: UIKit reads bodySmall (message text), labelMedium, labelSmall,
 *  headlineMedium, bodyMedium, titleSmall, bodyLarge, titleMedium, headlineSmall, titleLarge, labelLarge. */
fun brandTypography(font: FontFamily): Typography {
    val b = sendbirdTypography()
    return sendbirdTypography(
        displayLarge = b.displayLarge.copy(fontFamily = font),
        displayMedium = b.displayMedium.copy(fontFamily = font),
        displaySmall = b.displaySmall.copy(fontFamily = font),
        headlineLarge = b.headlineLarge.copy(fontFamily = font),
        headlineMedium = b.headlineMedium.copy(fontFamily = font),
        headlineSmall = b.headlineSmall.copy(fontFamily = font),
        titleLarge = b.titleLarge.copy(fontFamily = font),
        titleMedium = b.titleMedium.copy(fontFamily = font),
        titleSmall = b.titleSmall.copy(fontFamily = font),
        bodyLarge = b.bodyLarge.copy(fontFamily = font),
        bodyMedium = b.bodyMedium.copy(fontFamily = font),
        bodySmall = b.bodySmall.copy(fontFamily = font),
        labelLarge = b.labelLarge.copy(fontFamily = font),
        labelMedium = b.labelMedium.copy(fontFamily = font),
        labelSmall = b.labelSmall.copy(fontFamily = font),
    )
}

/** isDarkTheme follows the system and recomposes when it changes. Pass your own Boolean
 *  (for example from a settings toggle) to force a mode or switch at runtime. */
@Composable
fun BrandSendbirdTheme(
    isDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    SendbirdTheme(
        lightColorScheme = BrandLightColors,
        darkColorScheme = BrandDarkColors,
        typography = brandTypography(FontFamily.Serif), // or FontFamily(Font(R.font.your_font))
        isDarkTheme = isDark,
    ) { content() }
}

/** All UIKit group-channel screens with the brand theme. */
@Composable
fun BrandSendbirdScreens(navController: NavHostController) {
    NavHost(navController = navController, startDestination = SendbirdNavigation.GroupChannel.route) {
        sendbirdGroupChannelNavGraph(
            navController = navController,
            theme = { content -> BrandSendbirdTheme { content() } },
            // Optional: bubble colors for outgoing text messages only, without changing colorScheme.primary.
            channelScreen = { channelUrl -> BrandChannelScreen(navController, channelUrl) },
        )
    }
}

/** Replaces only the outgoing text bubble's colors. The messageItem slot does not pass the emoji
 *  reaction handlers, so reaction taps on rows drawn here use MessageItemFactory's defaults. */
@Composable
fun BrandChannelScreen(navController: NavHostController, channelUrl: String) {
    ChannelScreen(
        navController = navController,
        channelUrl = channelUrl,
        messageItem = { prevMessage, message, nextMessage, onMessageClick, onMessageLongClick ->
            MessageItemFactory(
                prevMessage = prevMessage,
                message = message,
                nextMessage = nextMessage,
                onMessageClick = onMessageClick,
                onMessageLongClick = onMessageLongClick,
                myTextMessageItem = { userMessage ->
                    MyTextMessageItem(
                        message = userMessage,
                        onMessageClick = { onMessageClick(it) },
                        onMessageLongClick = { onMessageLongClick(it) },
                        textBackgroundColor = Color(0xFF0B8043),
                        textColor = Color.White,
                    )
                },
            )
        },
    )
}
