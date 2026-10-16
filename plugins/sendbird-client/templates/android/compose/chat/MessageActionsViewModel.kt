// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-base-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: knowledge/curated/android/products/chat.md ("Update and delete a message")
// SDK calls (updateUserMessage, deleteMessage, SendbirdChat currentUser / addChannelHandler / removeChannelHandler,
// GroupChannelHandler onMessageUpdated / onMessageDeleted) are the ones in the View-host template
// templates/android/view/chat/MessageEditing.kt, verified with javap on the sendbird-chat 4.36.4 and 4.36.5 AARs. This file
// only wraps them in a ViewModel with a SharedFlow; the wrapper is standard AndroidX/coroutines, not an SDK API.
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.compose.chat

import androidx.lifecycle.ViewModel
import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.message.UserMessage
import com.sendbird.android.params.UserMessageUpdateParams
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/** An edit or delete that happened in the open conversation (by this user or another member). */
sealed interface MessageChange {
    data class Updated(val message: BaseMessage) : MessageChange
    data class Deleted(val messageId: Long) : MessageChange
}

/**
 * Edit and delete for one conversation, plus the edits and deletes other members make. Collect [changes] in a
 * LaunchedEffect and update the shown list. An app that already shows messages through a MessageCollection gets
 * other members' changes from the collection and can skip [watch].
 */
class MessageActionsViewModel : ViewModel() {
    private val _changes = MutableSharedFlow<MessageChange>(extraBufferCapacity = 16)
    val changes: SharedFlow<MessageChange> = _changes.asSharedFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    private var handlerId: String? = null

    /** True when the connected user sent [message]; offer Edit and Delete only for those. */
    fun isMine(message: BaseMessage): Boolean {
        val me = SendbirdChat.currentUser ?: return false
        return message.sender?.userId == me.userId
    }

    fun edit(channel: GroupChannel, message: UserMessage, newText: String) {
        channel.updateUserMessage(message.messageId, UserMessageUpdateParams(newText)) { updated, e ->
            if (updated != null) _changes.tryEmit(MessageChange.Updated(updated))
            if (e != null) _error.value = e.message
        }
    }

    fun delete(channel: GroupChannel, message: BaseMessage) {
        val messageId = message.messageId
        channel.deleteMessage(message) { e ->
            if (e == null) _changes.tryEmit(MessageChange.Deleted(messageId)) else _error.value = e.message
        }
    }

    /** Starts receiving other members' edits and deletes for [channelUrl]; stops in onCleared. */
    fun watch(channelUrl: String) {
        if (handlerId != null) return
        val id = "message-actions-$channelUrl"
        handlerId = id
        SendbirdChat.addChannelHandler(id, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}

            override fun onMessageUpdated(channel: BaseChannel, message: BaseMessage) {
                if (channel.url == channelUrl) _changes.tryEmit(MessageChange.Updated(message))
            }

            override fun onMessageDeleted(channel: BaseChannel, msgId: Long) {
                if (channel.url == channelUrl) _changes.tryEmit(MessageChange.Deleted(msgId))
            }
        })
    }

    override fun onCleared() {
        handlerId?.let { SendbirdChat.removeChannelHandler(it) }
    }
}
