// source: knowledge/curated/android/cross-cutting/errors.md ("All codes", "Handling tips")
// source: knowledge/curated/android/products/chat.md ("Call APIs only after connect completes")
package com.example.starterbp.view.sendbird

import com.sendbird.android.exception.SendbirdError
import com.sendbird.android.exception.SendbirdException

/**
 * BP13: the error code and the next step, chosen from the verified error table.
 * tokenSent: whether connect sent a session token. Without one, 400302 means the application does not
 * allow connecting with a user ID alone, or this user has been issued a token; signing in again sends
 * no token either, so the text points at the token hook instead.
 */
class SendbirdErrorView(e: SendbirdException, tokenSent: Boolean = true) {
    val code: Int = e.code

    /** true when the user has to sign in again (the token or the user is no longer valid) */
    val signInAgain: Boolean = code in setOf(
        SendbirdError.ERR_USER_DEACTIVATED,      // 400300
        SendbirdError.ERR_USER_NOT_EXIST,        // 400301
        SendbirdError.ERR_INVALID_TOKEN,         // 400302
        SendbirdError.ERR_SESSION_TOKEN_REVOKED, // 400310
    )

    val text: String = when {
        code == SendbirdError.ERR_INVALID_TOKEN && !tokenSent ->
            "Sign-in needs a session token ($code). Return one from TokenProvider.fetchSessionToken."
        signInAgain -> "Sign in again ($code)."
        code == SendbirdError.ERR_CONNECTION_REQUIRED -> "Not connected yet ($code). Try again once the status shows Connected."
        code == SendbirdError.ERR_NETWORK -> "Network problem ($code). Check the connection and sign in again."
        else -> "Error $code: ${e.message}"
    }
}
