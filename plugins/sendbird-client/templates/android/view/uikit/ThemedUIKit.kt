// source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L107-L115 (ThemeMode Light and Dark only)
// source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/activities/ChannelListActivity.java#L114-L117 (UIKit Activities read the theme from the intent)
// source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/modules/ChannelListModule.java#L51-L53 (a fragment's module reads the default mode when created)
// Compiled with tools/templates/compile-check-android.sh (Kotlin only). The res XML in res/ was linked
// against UIKit 3.26.3 resources once (verifyReleaseResources, 2026-11-23); this repo's harness does not build res/.
// Guide: knowledge/curated/android/cross-cutting/theme.md ("Follow the system dark mode (View host)",
//   "Custom colors (View host)", "Fonts (View host)", "Message bubble colors (View host)").
//
// Dark mode that follows the system. Brand colors, the font, and bubble colors are resources:
// copy res/values/sendbird_brand.xml and res/color/*.xml into the app.
import android.app.Application
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.fragments.ChannelListFragment

/** UIKit has only Light and Dark; read the system night mode and pick one. */
fun uikitThemeModeFor(configuration: Configuration): SendbirdUIKit.ThemeMode {
    val night = configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return if (night == Configuration.UI_MODE_NIGHT_YES) SendbirdUIKit.ThemeMode.Dark else SendbirdUIKit.ThemeMode.Light
}

fun uikitThemeModeFor(context: Context): SendbirdUIKit.ThemeMode =
    uikitThemeModeFor(context.resources.configuration)

class ThemedUIKitApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Set the mode before any UIKit screen is created.
        SendbirdUIKit.setDefaultThemeMode(uikitThemeModeFor(this))
        // SendbirdUIKit.init(adapter, this)  — see UIKitApplication.kt
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Screens created from now on use the new mode.
        SendbirdUIKit.setDefaultThemeMode(uikitThemeModeFor(newConfig))
    }
}

/**
 * Hosts the UIKit channel list in your own Activity so the list follows a system dark mode switch
 * while it is open: the system recreates this Activity, the restored fragment builds its module again,
 * and the module reads SendbirdUIKit.getDefaultThemeMode() at that moment.
 * Give this Activity a DayNight app theme (for example Theme.AppCompat.DayNight.NoActionBar).
 */
class ChatHostActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super.onCreate: restored fragments are created inside super.onCreate.
        SendbirdUIKit.setDefaultThemeMode(uikitThemeModeFor(this))
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, ChannelListFragment.Builder().build())
                .commit()
        }
    }
}
