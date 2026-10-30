// source: knowledge/curated/android/products/uikit.md ("Initialize (Application class)", "Pitfalls")
// source: knowledge/curated/android/products/auth.md ("Session token expiry")
// source: knowledge/curated/android/products/chat.md ("Call APIs only after connect completes", "Connection state and reconnection")
// source: knowledge/curated/android/cross-cutting/theme.md ("Light / dark (View host)")
// source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/SendbirdUIKit.java#L557
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
package com.example.starterbp.view.sendbird

import android.app.Application
import android.os.Handler
import android.os.Looper
import com.example.starterbp.view.BuildConfig
import com.sendbird.android.SendbirdChat
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.ConnectionHandler
import com.sendbird.android.handler.InitResultHandler
import com.sendbird.android.handler.SessionHandler
import com.sendbird.android.handler.SessionTokenRequester
import com.sendbird.android.user.User
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.adapter.SendbirdUIKitAdapter
import com.sendbird.uikit.interfaces.UserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class Connection { CONNECTED, RECONNECTING, OFFLINE }

sealed interface SessionState {
    data class SignedOut(val notice: String? = null) : SessionState
    data class Connecting(val userId: String) : SessionState
    data class SignedIn(val userId: String, val connection: Connection) : SessionState
}

/**
 * BP16: the one app-wide Sendbird session. The sign-in screen, LoginService, a deep link, or a test
 * all call this object, and every screen collects [state], so a sign-in from any path moves the app
 * to the signed-in screens. Every method runs on the main thread.
 */
object SendbirdSession {
    private const val CONNECTION_HANDLER_ID = "starter-connection"
    private val main = Handler(Looper.getMainLooper())
    private val _state = MutableStateFlow<SessionState>(SessionState.SignedOut())
    val state: StateFlow<SessionState> = _state.asStateFlow()

    private var initialized = false
    private var signingOut = false
    private var pendingUserId: String? = null
    // Not named `accessToken`: inside the adapter below, that name would resolve to the adapter's
    // own getAccessToken() and recurse.
    private var sessionToken: String? = null

    val appIdConfigured: Boolean get() = BuildConfig.SENDBIRD_APP_ID.isNotBlank()

    val userId: String?
        get() = when (val s = _state.value) {
            is SessionState.SignedOut -> null
            is SessionState.Connecting -> s.userId
            is SessionState.SignedIn -> s.userId
        }

    val isConnected: Boolean get() = _state.value is SessionState.SignedIn

    /** BP01: initialize once, in Application.onCreate. BP12: theme before the first UIKit screen. */
    fun init(app: Application) {
        if (!appIdConfigured) return
        SendbirdUIKit.setDefaultThemeMode(SendbirdUIKit.ThemeMode.Light)
        // BP05: UIKit reads the App ID, the token, and the current user from this adapter when it
        // connects. BP11: UIKit always initializes the Chat SDK with local caching on.
        SendbirdUIKit.init(object : SendbirdUIKitAdapter {
            override fun getAppId(): String = BuildConfig.SENDBIRD_APP_ID
            override fun getAccessToken(): String? = sessionToken
            override fun getUserInfo(): UserInfo = object : UserInfo {
                override fun getUserId(): String = this@SendbirdSession.userId.orEmpty()
                override fun getNickname(): String = ""
                override fun getProfileUrl(): String = ""
            }
            override fun getInitResultHandler(): InitResultHandler = object : InitResultHandler {
                override fun onMigrationStarted() {}
                override fun onInitFailed(e: SendbirdException) {
                    main.post {
                        pendingUserId = null
                        _state.value = SessionState.SignedOut("Initialization failed (${e.code}).")
                    }
                }
                override fun onInitSucceed() {
                    main.post { didInitialize() }
                }
            }
        }, app)
    }

    private fun didInitialize() {
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
            main.post {
                if (_state.value != SessionState.Connecting(userId)) return@post
                sessionToken = token
                // BP05: connect through UIKit so it knows the current user.
                SendbirdUIKit.connect { user, e -> main.post { didConnect(userId, user, e) } }
            }
        }
    }

    private fun didConnect(userId: String, user: User?, e: SendbirdException?) {
        if (_state.value != SessionState.Connecting(userId)) return // signed out meanwhile
        val error = e?.let { SendbirdErrorView(it, tokenSent = sessionToken != null) }
        if (user == null || error?.signInAgain == true) {
            // BP13: show the code; the user signs in again.
            SendbirdChat.removeConnectionHandler(CONNECTION_HANDLER_ID)
            sessionToken = null
            _state.value = SessionState.SignedOut(error?.text ?: "Could not connect. Try again.")
            return
        }
        // With local caching, connect can return the user with an error: the app works from cached
        // data and the SDK connects later (onReconnectSucceeded). BP06: the channel list opens from here.
        val connection = if (e == null) Connection.CONNECTED else Connection.RECONNECTING
        _state.value = SessionState.SignedIn(userId, connection)
        PushTokens.registerForCurrentUser() // BP10
    }

    /**
     * BP09: unregister this device's push token first, then disconnect in its completion.
     * Disconnecting also clears the user's local cache.
     */
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
            SendbirdUIKit.disconnect { main.post { didSignOut(notice) } }
        }
    }

    private fun didSignOut(notice: String?) {
        signingOut = false
        sessionToken = null
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
            main.post { signOut("Your session ended. Sign in again.") }
        }

        override fun onSessionRefreshed() {}
        override fun onSessionError(sendbirdException: SendbirdException) {}
    }

    // BP07: the SDK reconnects by itself; this handler only drives the status line.
    private val connectionHandler = object : ConnectionHandler {
        override fun onConnected(userId: String) {
            main.post { setConnection(Connection.CONNECTED) }
        }
        override fun onDisconnected(userId: String) {}
        override fun onReconnectStarted() {
            main.post { setConnection(Connection.RECONNECTING) }
        }
        override fun onReconnectSucceeded() {
            main.post { setConnection(Connection.CONNECTED) }
        }
        override fun onReconnectFailed() {
            main.post { setConnection(Connection.OFFLINE) }
        }
    }
}
