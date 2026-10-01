// source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message (verified 2026-06-09)
// SDK calls (SendbirdChat.init / connect / sendUserMessage with UserMessageCreateParams) are
// identical to the verified View-host template (templates/android/view/chat/InitConnect.kt). This
// file only wraps them in a ViewModel exposing a StateFlow so Compose can observe state — the
// wrapper is standard AndroidX/coroutines, not an SDK API.
// Gradle: settings.gradle -> maven { setUrl("https://repo.sendbird.com/public/maven") }
//         build.gradle  -> implementation("com.sendbird.sdk:sendbird-chat:4.+")
// App ID from BuildConfig/secret; session/access tokens are secrets — never hard-code.

package com.sendbird.client.templatecheck.compose.chat

import androidx.lifecycle.ViewModel
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.params.UserMessageCreateParams

data class ChatUiState(
    val isConnected: Boolean = false,
    val userId: String? = null,
    val error: String? = null,
)

/** Observable Chat session for Compose. `SendbirdChat.init(...)` itself stays in the Application
 *  class (see templates/android/view/chat/InitConnect.kt); this VM handles connect + send + state. */
class ChatViewModel : ViewModel() {
    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    /** Connect after init. Authenticated apps: SendbirdChat.connect(userId, authToken) { ... }. */
    fun connectUser(userId: String) {
        SendbirdChat.connect(userId) { user, e ->
            _state.value = if (user != null) {
                ChatUiState(isConnected = true, userId = user.userId)
            } else {
                _state.value.copy(error = e?.message ?: "connect failed")
            }
        }
    }

    /** Send a text message to an already-loaded GroupChannel. */
    fun send(text: String, channel: GroupChannel) {
        channel.sendUserMessage(UserMessageCreateParams(text)) { _, e ->
            if (e != null) _state.value = _state.value.copy(error = e.message)
        }
    }
}

/** Minimal composable that reflects connection state. */
@Composable
fun ChatStatus(vm: ChatViewModel) {
    val state by vm.state.collectAsState()
    Column {
        Text(if (state.isConnected) "Connected: ${state.userId}" else "Not connected")
        state.error?.let { Text("Error: $it") }
    }
}
