// source: https://github.com/sendbird/sendbird-uikit-android/tree/main/uikit-samples
// Verified against MyFirebaseMessagingService.kt and BaseApplication.kt on 2026-09-22.
package com.sendbird.client.templatecheck.push

import android.content.Context
import com.google.firebase.messaging.RemoteMessage
import com.sendbird.android.push.SendbirdPushHandler
import com.sendbird.android.push.SendbirdPushHelper

class AppSendbirdPushHandler : SendbirdPushHandler() {
    override val isUniquePushToken: Boolean = false

    override fun onNewToken(newToken: String?) {
        // The SDK registers the new token for the connected user.
    }

    override fun onMessageReceived(context: Context, remoteMessage: RemoteMessage) {
        // Build the local notification and channel deep link here.
    }
}

fun registerSendbirdPushHandler() {
    SendbirdPushHelper.registerHandler(AppSendbirdPushHandler())
}
