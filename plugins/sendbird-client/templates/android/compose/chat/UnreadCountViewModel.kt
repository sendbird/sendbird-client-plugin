// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android/-sendbird-chat/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-group-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler
// source: knowledge/curated/android/products/chat.md ("Unread counts")
// SDK calls (getTotalUnreadMessageCount with UnreadMessageCountHandler, addUserEventHandler / removeUserEventHandler,
// UserEventHandler onTotalUnreadMessageCountChanged(UnreadMessageCount), GroupChannel unreadMessageCount / markAsRead) are the
// ones in the View-host template templates/android/view/chat/UnreadCount.kt, verified with javap on the sendbird-chat 4.36.4
// and 4.36.5 AARs. This file only wraps them in a ViewModel with a StateFlow; the wrapper is standard AndroidX/coroutines/
// Compose, not an SDK API. Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.compose.chat

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.handler.UnreadMessageCountHandler
import com.sendbird.android.handler.UserEventHandler
import com.sendbird.android.user.UnreadMessageCount
import com.sendbird.android.user.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The total unread message count for a tab badge. Scope it to the activity (or the nav graph that holds the
 * tabs) and call [start] after connect; it stops in onCleared.
 */
class UnreadCountViewModel : ViewModel() {
    private val _total = MutableStateFlow(0)
    val total: StateFlow<Int> = _total.asStateFlow()
    private val handlerId = "unread-count-viewmodel"
    private var started = false

    fun start() {
        if (started) return
        started = true
        SendbirdChat.addUserEventHandler(handlerId, object : UserEventHandler() {
            override fun onFriendsDiscovered(users: List<User>) {}

            override fun onTotalUnreadMessageCountChanged(unreadMessageCount: UnreadMessageCount) {
                _total.value = unreadMessageCount.groupChannelCount
            }
        })
        refresh()
    }

    /**
     * Fetches the total from the server. The Android docs say the live event above is turned off by default
     * (the app owner asks Sendbird to turn it on), so also call this when a screen resumes and after [markRead].
     */
    fun refresh() {
        SendbirdChat.getTotalUnreadMessageCount(handler = UnreadMessageCountHandler { groupChannelCount, _, e ->
            if (e == null) _total.value = groupChannelCount
        })
    }

    /** Resets one channel's count when the user opens it, then refreshes the total. */
    fun markRead(channel: GroupChannel) {
        channel.markAsRead { e -> if (e == null) refresh() }
    }

    /** The badge for one row of the channel list. */
    fun unreadCount(channel: GroupChannel): Int = channel.unreadMessageCount

    override fun onCleared() {
        if (started) SendbirdChat.removeUserEventHandler(handlerId)
    }
}

/** Minimal badge text; put it in a NavigationBarItem label or a BadgedBox. */
@Composable
fun UnreadCountBadge(vm: UnreadCountViewModel) {
    val total by vm.total.collectAsState()
    if (total > 0) Text(if (total > 99) "99+" else total.toString())
}
