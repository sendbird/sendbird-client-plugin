// source: https://github.com/sendbird/sendbird-uikit-sample-android-jetpack-compose/blob/main/uikit-compose-sample/src/main/java/com/sendbird/uikit/compose/sample/BaseApplication.kt (verified 2026-09-30)
// Symbols verified via javap of the published uikit-compose 1.3.6 AAR and its uikit-data 1.3.6
// dependency (2026-09-30):
//   - SendbirdUikitCompose.init(UikitInitParams): Flow<UikitInitResult>   (com.sendbird.uikit.compose)
//   - UikitInitParams(appId, context, isForeground, appVersion = default)  (com.sendbird.uikit.core.data.model)
//   - UikitInitResult { Started, Migrating, Success, Failure }             (com.sendbird.uikit.core.data.model)
// init returns a cold Flow — nothing happens until it is collected (the sample uses launchIn(MainScope())).
// Gradle: settings.gradle.kts -> maven { setUrl("https://repo.sendbird.com/public/maven") }
//         build.gradle.kts    -> implementation("com.sendbird.sdk:uikit-compose:1.3.6")
// Register in AndroidManifest.xml: <application android:name=".UikitComposeApplication" ...>
// App ID from BuildConfig/secret — never hard-code a real one.

package com.sendbird.client.templatecheck.compose.uikit

import android.app.Application
import com.sendbird.uikit.compose.SendbirdUikitCompose
import com.sendbird.uikit.core.data.model.UikitInitParams
import com.sendbird.uikit.core.data.model.UikitInitResult
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

private const val APP_ID = "YOUR_SENDBIRD_APP_ID"

class UikitComposeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SendbirdUikitCompose.init(
            UikitInitParams(appId = APP_ID, context = this, isForeground = true)
        ).onEach { result ->
            if (result == UikitInitResult.Failure) {
                // Initialization failed — log it and keep the UIKit screens hidden.
            }
        }.launchIn(MainScope())
        // Push: register your SendbirdPushHandler AFTER init (the sample calls
        // SendbirdPushHelper.registerHandler(...) here — see templates/android/view/chat/PushRegistration.kt).
    }
}
