package com.example.fixtureview.auth

/**
 * The app's own sign-in. Sendbird connects here after your sign-in succeeds,
 * and disconnects in onLogout.
 */
class LoginService {
    fun onLoginSucceeded(userId: String) {
        // Sendbird connect goes here.
    }

    fun onLogout() {
        // Sendbird disconnect goes here.
    }
}
