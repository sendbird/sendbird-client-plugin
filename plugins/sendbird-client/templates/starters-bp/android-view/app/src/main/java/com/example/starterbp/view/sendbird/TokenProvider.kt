// source: knowledge/curated/android/products/auth.md ("Connect (session token)", "Session token expiry")
package com.example.starterbp.view.sendbird

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
