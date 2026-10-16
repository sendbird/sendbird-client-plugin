// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/managing-read-status-in-a-group-channel/get-read-status
// source: knowledge/curated/android/products/chat.md ("Typing indicator (group channels)", "Read receipts for a message")
// Verified with javap on the sendbird-chat 4.36.4 and 4.36.5 AARs: GroupChannel startTyping(), endTyping(), typingUsers,
// markAsRead(CompletionHandler), getUnreadMemberCount(BaseMessage), getReadMembers(BaseMessage, boolean), url;
// GroupChannelHandler open onTypingStatusUpdated(GroupChannel) and onUserMarkedRead(GroupChannel, List<String>);
// SendbirdChat addChannelHandler / removeChannelHandler. Not used on purpose: onReadStatusUpdated, which is deprecated.
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.chat

import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.user.Member
import com.sendbird.android.user.User

/**
 * Typing indicator and read receipts for one open group channel screen. Call [start] in onCreate (or onStart)
 * and [stop] in onDestroy (or onStop).
 * [onTypingChanged] gets the users typing now; [onReadReceiptsChanged] means another member read messages,
 * so redraw the read marks with [unreadMemberCount].
 */
class ChannelActivityTracker(
    private val channelUrl: String,
    private val onTypingChanged: (List<User>) -> Unit,
    private val onReadReceiptsChanged: () -> Unit,
) {
    private val handlerId = "channel-activity-$channelUrl"

    fun start() {
        SendbirdChat.addChannelHandler(handlerId, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {}

            override fun onTypingStatusUpdated(channel: GroupChannel) {
                if (channel.url == channelUrl) onTypingChanged(channel.typingUsers)
            }

            override fun onUserMarkedRead(channel: GroupChannel, userIds: List<String>) {
                if (channel.url == channelUrl) onReadReceiptsChanged()
            }
        })
    }

    fun stop() {
        SendbirdChat.removeChannelHandler(handlerId)
    }

    companion object {
        /** Call from the input's TextWatcher: typing starts while there is text and ends when it is cleared.
         *  Also call `channel.endTyping()` right after sending. */
        fun onTextChanged(channel: GroupChannel, text: CharSequence) {
            if (text.isEmpty()) channel.endTyping() else channel.startTyping()
        }

        /** Call when the conversation is shown and when a new message arrives while it is on screen. */
        fun markRead(channel: GroupChannel) {
            channel.markAsRead { }
        }

        /** How many members have not read [message] yet; 0 means everyone has read it. */
        fun unreadMemberCount(channel: GroupChannel, message: BaseMessage): Int =
            channel.getUnreadMemberCount(message)

        /** Members (other than the current user) who have read [message]. */
        fun readers(channel: GroupChannel, message: BaseMessage): List<Member> =
            channel.getReadMembers(message, false)
    }
}
