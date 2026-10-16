// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler
// source: knowledge/curated/android/products/chat.md ("Unread counts")
// Verified with javap on the sendbird-chat 4.36.4 and 4.36.5 AARs: SendbirdChat getTotalUnreadMessageCount(params, UnreadMessageCountHandler)
// (params has a default, so the handler is passed by name), addUserEventHandler(String, UserEventHandler),
// removeUserEventHandler(String); UserEventHandler abstract onFriendsDiscovered(List<User>) and open
// onTotalUnreadMessageCountChanged(UnreadMessageCount); UnreadMessageCount groupChannelCount; GroupChannel unreadMessageCount,
// markAsRead(CompletionHandler). Not used on purpose: the CountHandler overloads and onTotalUnreadMessageCountChanged(Int, Map),
// deprecated since 4.6.0. Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.chat

import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.UnreadMessageCountHandler
import com.sendbird.android.handler.UserEventHandler
import com.sendbird.android.user.UnreadMessageCount
import com.sendbird.android.user.User

/**
 * Keeps a tab or app badge in step with the total number of unread messages in the user's group channels.
 * Call [start] after connect and [stop] on sign-out.
 */
class UnreadCountTracker(private val onChange: (Int) -> Unit) {
    private val handlerId = "unread-count-badge"

    fun start() {
        SendbirdChat.addUserEventHandler(handlerId, object : UserEventHandler() {
            override fun onFriendsDiscovered(users: List<User>) {}

            override fun onTotalUnreadMessageCountChanged(unreadMessageCount: UnreadMessageCount) {
                onChange(unreadMessageCount.groupChannelCount)
            }
        })
        refresh()
    }

    fun stop() {
        SendbirdChat.removeUserEventHandler(handlerId)
    }

    /**
     * Fetches the total from the server. The Android docs say the live event above is turned off by default
     * (the app owner asks Sendbird to turn it on), so also call this in onResume and after [markRead].
     */
    fun refresh() {
        SendbirdChat.getTotalUnreadMessageCount(handler = UnreadMessageCountHandler { groupChannelCount, _, e ->
            if (e == null) onChange(groupChannelCount)
        })
    }

    /** Resets one channel's count when the user opens it, then refreshes the total. */
    fun markRead(channel: GroupChannel) {
        channel.markAsRead { e -> if (e == null) refresh() }
    }

    companion object {
        /** The badge for one row of the channel list. */
        fun unreadCount(channel: GroupChannel): Int = channel.unreadMessageCount
    }
}
