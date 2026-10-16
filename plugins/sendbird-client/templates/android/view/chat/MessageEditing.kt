// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-base-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/managing-a-message/update-a-message
// source: knowledge/curated/android/products/chat.md ("Update and delete a message")
// Verified with javap on the sendbird-chat 4.36.4 and 4.36.5 AARs: BaseChannel updateUserMessage(long, UserMessageUpdateParams,
// UserMessageHandler), deleteMessage(BaseMessage, CompletionHandler), url; UserMessageUpdateParams(String); BaseMessage
// messageId, sender; SendbirdChat currentUser, addChannelHandler(String, BaseChannelHandler), removeChannelHandler(String);
// GroupChannelHandler with abstract onMessageReceived and open onMessageUpdated / onMessageDeleted.
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
// A user can update or delete messages they sent; channel operators can update or delete any message.
package com.sendbird.client.templatecheck.chat

import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.message.UserMessage
import com.sendbird.android.params.UserMessageUpdateParams

/** Edit and delete actions for the message list's long-press menu. */
object MessageEditor {
    /** True when the connected user sent [message]; show Edit and Delete only for those. */
    fun isMine(message: BaseMessage): Boolean {
        val me = SendbirdChat.currentUser ?: return false
        return message.sender?.userId == me.userId
    }

    /** Replaces the text of a user message. [onResult] gets the updated message to put in the list. */
    fun edit(channel: GroupChannel, message: UserMessage, newText: String, onResult: (UserMessage?, SendbirdException?) -> Unit) {
        channel.updateUserMessage(message.messageId, UserMessageUpdateParams(newText)) { updated, e -> onResult(updated, e) }
    }

    /** Deletes a message for everyone in the channel. Remove the row when [onResult] gets null. */
    fun delete(channel: GroupChannel, message: BaseMessage, onResult: (SendbirdException?) -> Unit) {
        channel.deleteMessage(message) { e -> onResult(e) }
    }
}

/**
 * Tells one open conversation screen that another member edited or deleted a message. Call [start] in onCreate
 * (or onStart) and [stop] in onDestroy (or onStop). An app that already shows messages through a MessageCollection
 * gets these changes from its collection handler instead and does not need this.
 */
class MessageChangeListener(
    private val channelUrl: String,
    private val onUpdated: (BaseMessage) -> Unit,
    private val onDeleted: (Long) -> Unit,
) {
    private val handlerId = "message-changes-$channelUrl"

    fun start() {
        SendbirdChat.addChannelHandler(handlerId, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}

            override fun onMessageUpdated(channel: BaseChannel, message: BaseMessage) {
                if (channel.url == channelUrl) onUpdated(message)
            }

            override fun onMessageDeleted(channel: BaseChannel, msgId: Long) {
                if (channel.url == channelUrl) onDeleted(msgId)
            }
        })
    }

    fun stop() {
        SendbirdChat.removeChannelHandler(handlerId)
    }
}
