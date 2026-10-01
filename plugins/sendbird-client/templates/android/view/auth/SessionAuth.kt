// source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication
//   (verified 2026-06-10); import paths verified via org-wide code search of public Sendbird repos.
// NOT compiled in-repo (no Android toolchain). Auth is part of Chat. Tokens are secrets — never hard-code.

import com.sendbird.android.SendbirdChat
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.SessionHandler
import com.sendbird.android.handler.SessionTokenRequester

object SessionAuth {

    // Set before connecting.
    fun installSessionHandler() {
        SendbirdChat.setSessionHandler(object : SessionHandler() {
            override fun onSessionTokenRequired(sessionTokenRequester: SessionTokenRequester) {
                // fetch a new token from your server, then:
                //   sessionTokenRequester.onSuccess(NEW_TOKEN)  — refresh
                //   sessionTokenRequester.onSuccess(null)        — skip
                //   sessionTokenRequester.onFail()               — error
            }
            override fun onSessionClosed() { /* route the user to login */ }
            override fun onSessionRefreshed() { }
            override fun onSessionError(e: SendbirdException) { }
        })
    }

    fun connect(userId: String, authToken: String?) {
        SendbirdChat.connect(userId, authToken) { user, _ ->
            if (user != null) { /* connected */ }
        }
    }

    fun logout() {
        SendbirdChat.disconnect { /* disconnected; local data cleared */ }
    }
}
