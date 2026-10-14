// source: knowledge/curated/android/cross-cutting/errors.md ("All codes", "Handling tips")
// source: knowledge/curated/android/products/chat.md ("Call APIs only after connect completes")
package com.example.starterbp.view.sendbird

import com.sendbird.android.exception.SendbirdError
import com.sendbird.android.exception.SendbirdException

/** BP13: the error code and the next step, chosen from the verified error table. */
class SendbirdErrorView(e: SendbirdException) {
    val code: Int = e.code

    /** true when the user has to sign in again (the token or the user is no longer valid) */
    val signInAgain: Boolean = code in setOf(
        SendbirdError.ERR_USER_DEACTIVATED,      // 400300
        SendbirdError.ERR_USER_NOT_EXIST,        // 400301
        SendbirdError.ERR_INVALID_TOKEN,         // 400302
        SendbirdError.ERR_SESSION_TOKEN_REVOKED, // 400310
    )

    val text: String = when {
        signInAgain -> "Sign in again ($code)."
        code == SendbirdError.ERR_CONNECTION_REQUIRED -> "Not connected yet ($code). Try again once the status shows Connected."
        code == SendbirdError.ERR_NETWORK -> "Network problem ($code). Check the connection and sign in again."
        else -> "Error $code: ${e.message}"
    }
}
