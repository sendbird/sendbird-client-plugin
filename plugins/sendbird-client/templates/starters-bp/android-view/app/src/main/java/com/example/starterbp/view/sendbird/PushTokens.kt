// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
package com.example.starterbp.view.sendbird

import com.sendbird.android.SendbirdChat

/**
 * BP10: the push token registration point (manual path, no Firebase in the starter). After you add
 * Firebase Cloud Messaging, hand each new FCM token to [onNewToken]; it is registered only for the
 * signed-in user, after connect. If you use a SendbirdPushHandler instead, register the handler
 * after init and replace [unregisterThen] with SendbirdPushHelper.unregisterHandler (push doc).
 */
object PushTokens {
    private var latestToken: String? = null
    private var registeredToken: String? = null

    fun onNewToken(token: String) {
        latestToken = token
        if (SendbirdSession.isConnected) registerForCurrentUser()
    }

    internal fun registerForCurrentUser() {
        val token = latestToken ?: return
        SendbirdChat.registerPushToken(token) { _, e ->
            if (e == null) registeredToken = token
        }
    }

    /** BP09: unregister this device's token first, then run [next] (the disconnect). */
    internal fun unregisterThen(next: () -> Unit) {
        val token = registeredToken ?: return next()
        SendbirdChat.unregisterPushToken(token) { _ ->
            registeredToken = null
            next()
        }
    }
}
