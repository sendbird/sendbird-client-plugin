// source: sendbird-uikit-android uikit-samples BaseApplication.kt (public repo
//   github.com/sendbird/sendbird-uikit-android; verified 2026-06-09)
// Imports + calls copied verbatim from the sample. NOT compiled in-repo (no Android toolchain).
// Gradle: maven { setUrl("https://repo.sendbird.com/public/maven") } + implementation("com.sendbird.sdk:uikit:3.26.2")
// App ID from BuildConfig/secret; access token is a secret — never hard-code.

import android.app.Application
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.InitResultHandler
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.adapter.SendbirdUIKitAdapter
import com.sendbird.uikit.interfaces.UserInfo

private const val APP_ID = "YOUR_SENDBIRD_APP_ID"

class UIKitApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val adapter = object : SendbirdUIKitAdapter {
            override fun getAppId(): String = APP_ID
            override fun getAccessToken(): String? = null   // return a session/access token for authenticated apps
            override fun getUserInfo(): UserInfo = object : UserInfo {
                override fun getUserId(): String = "YOUR_USER_ID"
                override fun getNickname(): String = ""
                override fun getProfileUrl(): String = ""
            }
            override fun getInitResultHandler(): InitResultHandler = object : InitResultHandler {
                override fun onMigrationStarted() { }
                override fun onInitFailed(e: SendbirdException) { }
                override fun onInitSucceed() { }
            }
        }
        SendbirdUIKit.setDefaultThemeMode(SendbirdUIKit.ThemeMode.Light)
        SendbirdUIKit.init(adapter, this)
    }
}
