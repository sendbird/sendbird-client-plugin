// source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication (verified 2026-06-10)
// SDK calls are the same ones as the View-host template (templates/android/view/auth/SessionAuth.kt),
// re-verified via javap of the published sendbird-chat 4.36.4 and 4.36.5 AARs (2026-09-30):
//   - SendbirdChat.setSessionHandler(SessionHandler) / connect(userId, authToken, ConnectHandler) / disconnect(DisconnectHandler)
//   - abstract SessionHandler: onSessionTokenRequired(SessionTokenRequester), onSessionClosed()
//     (+ open onSessionRefreshed(), onSessionError(SendbirdException))
//   - SessionTokenRequester.onSuccess(String?) / onFail()
// This file only wraps them in a ViewModel exposing a StateFlow so Compose can observe the session —
// the wrapper is standard AndroidX/coroutines, not an SDK API. Auth is part of Chat:
// SendbirdChat.init(...) stays in the Application (templates/android/view/chat/InitConnect.kt).
// Tokens are secrets — fetch them from your server; never hard-code or log them.

package com.sendbird.client.templatecheck.compose.auth

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import com.sendbird.android.SendbirdChat
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.SessionHandler
import com.sendbird.android.handler.SessionTokenRequester
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed interface AuthState {
    data object LoggedOut : AuthState
    data object Connecting : AuthState
    data class Connected(val userId: String) : AuthState
    /** The SDK could not refresh the session (onSessionClosed) — send the user back to login. */
    data object SessionClosed : AuthState
    data class Failed(val message: String) : AuthState
}

class AuthViewModel : ViewModel() {
    private val _state = MutableStateFlow<AuthState>(AuthState.LoggedOut)
    val state: StateFlow<AuthState> = _state.asStateFlow()

    /** Call once before connect(). `fetchToken` asks YOUR server for a fresh session token and
     *  reports back through the requester: onSuccess(token) refresh, onSuccess(null) skip, onFail() error. */
    fun installSessionHandler(fetchToken: (SessionTokenRequester) -> Unit) {
        SendbirdChat.setSessionHandler(object : SessionHandler() {
            override fun onSessionTokenRequired(sessionTokenRequester: SessionTokenRequester) {
                fetchToken(sessionTokenRequester)
            }
            override fun onSessionClosed() { _state.value = AuthState.SessionClosed }
            override fun onSessionRefreshed() { }
            override fun onSessionError(e: SendbirdException) {
                _state.value = AuthState.Failed(e.message ?: "session error")
            }
        })
    }

    fun connect(userId: String, authToken: String?) {
        _state.value = AuthState.Connecting
        SendbirdChat.connect(userId, authToken) { user, e ->
            _state.value = if (user != null) {
                AuthState.Connected(user.userId)
            } else {
                AuthState.Failed(e?.message ?: "connect failed")
            }
        }
    }

    fun logout() {
        SendbirdChat.disconnect { _state.value = AuthState.LoggedOut }
    }
}

/** Minimal composable that follows the session state. */
@Composable
fun AuthStatus(vm: AuthViewModel, onLoginRequired: () -> Unit) {
    val state by vm.state.collectAsState()
    Column {
        when (val s = state) {
            AuthState.LoggedOut, AuthState.SessionClosed -> Button(onClick = onLoginRequired) { Text("Log in") }
            AuthState.Connecting -> Text("Connecting…")
            is AuthState.Connected -> {
                Text("Signed in as ${s.userId}")
                Button(onClick = { vm.logout() }) { Text("Log out") }
            }
            is AuthState.Failed -> Text("Error: ${s.message}")
        }
    }
}
