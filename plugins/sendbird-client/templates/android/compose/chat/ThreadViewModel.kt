// source: https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/create-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/list-replies-in-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.message/-base-message/index.html
// source: knowledge/curated/android/products/chat.md ("Message threads")
// SDK calls (getThreadedMessagesByTimestamp, ThreadMessageListParams, UserMessageCreateParams parentMessageId,
// sendUserMessage, SendbirdChat addChannelHandler / removeChannelHandler, GroupChannelHandler onMessageReceived,
// onThreadInfoUpdated) are the ones in the View-host template templates/android/view/chat/MessageThreads.kt, verified with
// javap on the sendbird-chat 4.36.5 AAR. The handler's reply list is List<BaseMessage>? to Kotlin, hence orEmpty().
// This file only wraps them in a ViewModel with a StateFlow; the wrapper is standard AndroidX/coroutines, not an SDK API.
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.compose.chat

import androidx.lifecycle.ViewModel
import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.params.ThreadMessageListParams
import com.sendbird.android.params.UserMessageCreateParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * One thread screen: the replies of a root message, sending a reply, and new replies as they arrive. Call [open] once with
 * the message the user tapped; collect [replies] with collectAsState(). The handler is removed in onCleared.
 */
class ThreadViewModel : ViewModel() {
    private val _replies = MutableStateFlow<List<BaseMessage>>(emptyList())
    val replies: StateFlow<List<BaseMessage>> = _replies.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    private var handlerId: String? = null
    private var rootId = 0L

    /** Threads are one level deep: a reply to a reply belongs to the same root message. */
    fun open(channel: GroupChannel, message: BaseMessage, limit: Int = 100) {
        if (handlerId != null) return
        val root = if (message.parentMessageId != 0L) message.parentMessageId else message.messageId
        rootId = root
        val id = "thread-${channel.url}-$root"
        handlerId = id
        SendbirdChat.addChannelHandler(id, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {
                if (message.parentMessageId == rootId) add(message)
            }
        })
        val params = ThreadMessageListParams().apply {
            previousResultSize = 0
            nextResultSize = limit
        }
        // replies are listed from the given message's timestamp on, so open the thread from its root message
        // (parentMessageId == 0) to list every reply
        message.getThreadedMessagesByTimestamp(message.createdAt, params) { _, list, e ->
            if (e != null) _error.value = e.message
            list.orEmpty().forEach { add(it) }
        }
    }

    fun reply(channel: GroupChannel, text: String) {
        val params = UserMessageCreateParams(text).apply { parentMessageId = rootId }
        channel.sendUserMessage(params) { sent, e ->
            if (sent != null) add(sent)
            if (e != null) _error.value = e.message
        }
    }

    private fun add(message: BaseMessage) {
        val current = _replies.value
        if (current.any { it.messageId == message.messageId }) return
        _replies.value = (current + message).sortedBy { it.createdAt }
    }

    override fun onCleared() {
        handlerId?.let { SendbirdChat.removeChannelHandler(it) }
    }
}
