// source: knowledge/curated/android/cross-cutting/push.md ("Handler-based vs manual token registration", "Logout: unregister this device before disconnecting"); knowledge/curated/android/hosts/compose.md ("UIKit for Jetpack Compose — init, then push")
package com.example.starterbp.compose.sendbird

import com.sendbird.android.SendbirdChat

/**
 * BP10: the push token registration point (manual path, no Firebase in the starter). After you add
 * FCM, hand each new token to [onNewToken]; it is registered only for the signed-in user, after connect.
 * With a SendbirdPushHandler instead, register it after init AND again after connect (compose.md
 * "UIKit for Jetpack Compose — init, then push"), and make [unregisterThen] call unregisterHandler.
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
