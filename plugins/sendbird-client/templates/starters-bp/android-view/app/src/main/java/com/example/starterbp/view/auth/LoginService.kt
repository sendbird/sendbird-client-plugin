package com.example.starterbp.view.auth

import com.example.starterbp.view.sendbird.SendbirdSession

/**
 * The app's own sign-in calls these. Sendbird connects after [onLoginSucceeded] and disconnects in
 * [onLogout]. Any instance works: both forward to the one app-wide session (BP16), so a sign-in
 * from the sign-in screen, a deep link, or a test reaches the same place. Call on the main thread.
 */
class LoginService {
    fun onLoginSucceeded(userId: String) {
        SendbirdSession.signIn(userId)
    }

    fun onLogout() {
        SendbirdSession.signOut()
    }
}
