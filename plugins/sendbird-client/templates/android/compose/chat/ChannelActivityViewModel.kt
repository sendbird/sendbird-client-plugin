// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: knowledge/curated/android/products/chat.md ("Typing indicator (group channels)", "Read receipts for a message")
// SDK calls (GroupChannel startTyping / endTyping / typingUsers / markAsRead / getUnreadMemberCount, GroupChannelHandler
// onTypingStatusUpdated / onUserMarkedRead, SendbirdChat addChannelHandler / removeChannelHandler) are the ones in the
// View-host template templates/android/view/chat/TypingAndReadReceipts.kt, verified with javap on the sendbird-chat 4.36.4 and
// 4.36.5 AARs. This file only wraps them in a ViewModel with StateFlows; the wrapper is standard AndroidX/coroutines/Compose,
// not an SDK API. Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.compose.chat

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** "Alice is typing…" and read marks for one conversation screen. Call [watch] once; it stops in onCleared. */
class ChannelActivityViewModel : ViewModel() {
    private val _typingNames = MutableStateFlow<List<String>>(emptyList())
    /** Nicknames of the users typing now. */
    val typingNames: StateFlow<List<String>> = _typingNames.asStateFlow()
    private val _readReceiptsVersion = MutableStateFlow(0)
    /** Goes up each time another member reads messages; read it where read marks are drawn so they recompose. */
    val readReceiptsVersion: StateFlow<Int> = _readReceiptsVersion.asStateFlow()
    private var handlerId: String? = null

    fun watch(channel: GroupChannel) {
        if (handlerId != null) return
        val channelUrl = channel.url
        val id = "channel-activity-$channelUrl"
        handlerId = id
        SendbirdChat.addChannelHandler(id, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}

            override fun onTypingStatusUpdated(channel: GroupChannel) {
                if (channel.url == channelUrl) _typingNames.value = channel.typingUsers.map { it.nickname }
            }

            override fun onUserMarkedRead(channel: GroupChannel, userIds: List<String>) {
                if (channel.url == channelUrl) _readReceiptsVersion.value += 1
            }
        })
        channel.markAsRead { }
    }

    /** Call from the text field's onValueChange; call [sent] after sending. */
    fun onTextChanged(channel: GroupChannel, text: String) {
        if (text.isEmpty()) channel.endTyping() else channel.startTyping()
    }

    fun sent(channel: GroupChannel) = channel.endTyping()

    /** Call when a new message arrives while the conversation is on screen. */
    fun markRead(channel: GroupChannel) = channel.markAsRead { }

    /** How many members have not read [message]; 0 means everyone has. */
    fun unreadMemberCount(channel: GroupChannel, message: BaseMessage): Int = channel.getUnreadMemberCount(message)

    override fun onCleared() {
        handlerId?.let { SendbirdChat.removeChannelHandler(it) }
    }
}

/** "… is typing" line above the input. */
@Composable
fun TypingIndicator(vm: ChannelActivityViewModel) {
    val names by vm.typingNames.collectAsState()
    if (names.isNotEmpty()) Text("${names.joinToString()} ${if (names.size == 1) "is" else "are"} typing…")
}
