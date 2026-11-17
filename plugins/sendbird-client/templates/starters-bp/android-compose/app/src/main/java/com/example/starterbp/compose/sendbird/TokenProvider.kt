// source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication
package com.example.starterbp.compose.sendbird

/**
 * BP03 / BP04: the one place that asks your server for a Sendbird session token. It returns no
 * token, which works only with an application that allows connecting with a user ID alone.
 * Replace the body with a call to your server. Tokens are secrets: never hard-code, log, or commit them.
 */
object TokenProvider {
    fun fetchSessionToken(userId: String, callback: (String?) -> Unit) {
        callback(null)
    }
}
