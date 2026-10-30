// source: knowledge/curated/android/hosts/compose.md ("UIKit for Jetpack Compose — init, then push")
// source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/authentication
// source: knowledge/curated/android/products/auth.md ("Session token expiry")
// source: knowledge/curated/android/products/chat.md ("Call APIs only after connect completes", "Connection state and reconnection")
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
package com.example.starterbp.compose.sendbird

import android.app.Application
import com.example.starterbp.compose.BuildConfig
import com.sendbird.android.ConnectionState
import com.sendbird.android.SendbirdChat
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.ConnectionHandler
import com.sendbird.android.handler.SessionHandler
import com.sendbird.android.handler.SessionTokenRequester
import com.sendbird.uikit.compose.SendbirdUikitCompose
import com.sendbird.uikit.core.data.model.UikitCurrentUserInfo
import com.sendbird.uikit.core.data.model.UikitInitParams
import com.sendbird.uikit.core.data.model.UikitInitResult
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch

enum class Connection { CONNECTED, RECONNECTING, OFFLINE }

sealed interface SessionState {
    data class SignedOut(val notice: String? = null) : SessionState
    data class Connecting(val userId: String) : SessionState
    data class SignedIn(val userId: String, val connection: Connection) : SessionState
}

/**
 * BP16: the one app-wide Sendbird session. The sign-in screen, LoginService, a deep link, or a test
 * all call this object, and the UI collects [state], so a sign-in from any path moves the app to
 * the signed-in screens. Every method runs on the main thread.
 */
object SendbirdSession {
    private const val CONNECTION_HANDLER_ID = "starter-connection"
    private val scope = MainScope()
    private val _state = MutableStateFlow<SessionState>(SessionState.SignedOut())
    val state: StateFlow<SessionState> = _state.asStateFlow()

    private var initialized = false
    private var signingOut = false
    private var pendingUserId: String? = null

    val appIdConfigured: Boolean get() = BuildConfig.SENDBIRD_APP_ID.isNotBlank()

    val userId: String?
        get() = when (val s = _state.value) {
            is SessionState.SignedOut -> null
            is SessionState.Connecting -> s.userId
            is SessionState.SignedIn -> s.userId
        }

    val isConnected: Boolean get() = _state.value is SessionState.SignedIn

    /**
     * BP01: initialize once, in Application.onCreate. init returns a cold Flow, so it is collected.
     * BP11: UikitInitParams becomes the Chat SDK InitParams with local caching on (uikit-data 1.3.6).
     */
    fun init(app: Application) {
        if (!appIdConfigured) return
        SendbirdUikitCompose.init(
            UikitInitParams(appId = BuildConfig.SENDBIRD_APP_ID, context = app, isForeground = true)
        ).onEach { result ->
            when (result) {
                UikitInitResult.Success -> didInitialize()
                UikitInitResult.Failure -> {
                    pendingUserId = null
                    _state.value = SessionState.SignedOut("Initialization failed.")
                }
                else -> Unit
            }
        }.launchIn(scope)
    }

    private fun didInitialize() {
        if (initialized) return
        initialized = true
        // BP04: the session handler is set once, before any connect.
        SendbirdChat.setSessionHandler(sessionHandler)
        pendingUserId?.let { next ->
            pendingUserId = null
            _state.value = SessionState.SignedOut()
            signIn(next)
        }
    }

    /** BP03: connect only after the app's own sign-in succeeded, with that user's ID. */
    fun signIn(rawUserId: String) {
        val userId = rawUserId.trim()
        if (userId.isEmpty() || userId == this.userId) return
        if (!initialized) {
            pendingUserId = userId // signs in as soon as initialization completes
            _state.value = SessionState.Connecting(userId)
            return
        }
        if (signingOut || this.userId != null) {
            pendingUserId = userId // signs in after the current user is signed out
            signOut()
            return
        }
        _state.value = SessionState.Connecting(userId)
        // BP07 / BP08: the connection handler is added before connect and removed on sign-out.
        SendbirdChat.addConnectionHandler(CONNECTION_HANDLER_ID, connectionHandler)
        TokenProvider.fetchSessionToken(userId) { token ->
            scope.launch {
                if (_state.value != SessionState.Connecting(userId)) return@launch
                // BP05: tell UIKit who the user is, then connect through UIKit.
                SendbirdUikitCompose.prepare(UikitCurrentUserInfo(userId = userId, authToken = token))
                val result = runCatching { SendbirdUikitCompose.connect() }
                didConnect(userId, result.exceptionOrNull(), tokenSent = token != null)
            }
        }
    }

    private fun didConnect(userId: String, error: Throwable?, tokenSent: Boolean) {
        if (_state.value != SessionState.Connecting(userId)) return // signed out meanwhile
        if (error != null) {
            // BP13: show the code; the user signs in again.
            SendbirdChat.removeConnectionHandler(CONNECTION_HANDLER_ID)
            val text = (error as? SendbirdException)?.let { SendbirdErrorView(it, tokenSent).text }
            _state.value = SessionState.SignedOut(text ?: "Could not connect. Try again.")
            return
        }
        // BP06: the channel list opens from here on. With the local cache the socket may still be
        // opening; onConnected / onReconnectSucceeded update the status line.
        val open = SendbirdChat.connectionState == ConnectionState.OPEN
        _state.value = SessionState.SignedIn(userId, if (open) Connection.CONNECTED else Connection.RECONNECTING)
        PushTokens.registerForCurrentUser() // BP10
    }

    /** BP09: unregister this device's push token first, then disconnect. */
    fun signOut(notice: String? = null) {
        if (userId == null || signingOut) return
        if (!initialized) {
            pendingUserId = null
            _state.value = SessionState.SignedOut(notice)
            return
        }
        signingOut = true
        SendbirdChat.removeConnectionHandler(CONNECTION_HANDLER_ID) // BP08
        PushTokens.unregisterThen {
            scope.launch {
                runCatching { SendbirdUikitCompose.disconnect() }
                didSignOut(notice)
            }
        }
    }

    private fun didSignOut(notice: String?) {
        signingOut = false
        _state.value = SessionState.SignedOut(notice)
        pendingUserId?.let { next ->
            pendingUserId = null
            signIn(next)
        }
    }

    private fun setConnection(connection: Connection) {
        val s = _state.value
        if (s is SessionState.SignedIn) _state.value = s.copy(connection = connection)
    }

    // BP04: the token refresh hook. Answer with a new token, or onFail() to give up.
    private val sessionHandler = object : SessionHandler() {
        override fun onSessionTokenRequired(sessionTokenRequester: SessionTokenRequester) {
            val id = userId ?: return sessionTokenRequester.onFail()
            TokenProvider.fetchSessionToken(id) { token ->
                if (token != null) sessionTokenRequester.onSuccess(token) else sessionTokenRequester.onFail()
            }
        }

        override fun onSessionClosed() {
            scope.launch { signOut("Your session ended. Sign in again.") }
        }

        override fun onSessionRefreshed() {}
        override fun onSessionError(sendbirdException: SendbirdException) {}
    }

    // BP07: the SDK reconnects by itself; this handler only drives the status line.
    private val connectionHandler = object : ConnectionHandler {
        override fun onConnected(userId: String) {
            scope.launch { setConnection(Connection.CONNECTED) }
        }
        override fun onDisconnected(userId: String) {}
        override fun onReconnectStarted() {
            scope.launch { setConnection(Connection.RECONNECTING) }
        }
        override fun onReconnectSucceeded() {
            scope.launch { setConnection(Connection.CONNECTED) }
        }
        override fun onReconnectFailed() {
            scope.launch { setConnection(Connection.OFFLINE) }
        }
    }
}
