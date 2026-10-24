// source: https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/create-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/using-message-threading/list-replies-in-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.message/-base-message/index.html
// source: knowledge/curated/android/products/chat.md ("Message threads")
// Verified with javap on the sendbird-chat 4.36.5 AAR: BaseMessage getMessageId(), getParentMessageId(), getCreatedAt(),
// getThreadedMessagesByTimestamp(long, ThreadMessageListParams, ThreadedMessagesHandler); ThreadMessageListParams() with
// BaseMessageListParams setPreviousResultSize(int) / setNextResultSize(int); UserMessageCreateParams(String) with
// BaseMessageCreateParams setParentMessageId(long); BaseChannel sendUserMessage(UserMessageCreateParams, UserMessageHandler);
// SendbirdChat addChannelHandler(String, BaseChannelHandler), removeChannelHandler(String); GroupChannelHandler
// onMessageReceived; BaseChannelHandler onThreadInfoUpdated(BaseChannel, ThreadInfoUpdateEvent); BaseMessage getThreadInfo()
// and ThreadInfo getReplyCount() (4.36.4 and 4.36.5). Kotlin sees threadInfo as not nullable, so replyCount reads it directly.
// The Kotlin compiler sees ThreadedMessagesHandler's list as List<BaseMessage>? (2026-10-24: a thread screen that passed it
// to addAll() did not build), so every list below goes through orEmpty().
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.chat

import com.sendbird.android.SendbirdChat
import com.sendbird.android.channel.BaseChannel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.GroupChannelHandler
import com.sendbird.android.message.BaseMessage
import com.sendbird.android.message.ThreadInfoUpdateEvent
import com.sendbird.android.message.UserMessage
import com.sendbird.android.params.ThreadMessageListParams
import com.sendbird.android.params.UserMessageCreateParams

/** Replies in a message thread. Threads are one level deep: every reply points at the thread's root message. */
object MessageThreads {
    /** The ID a reply must carry: the root message's ID, also when the user replies to a reply. */
    fun rootId(message: BaseMessage): Long =
        if (message.parentMessageId != 0L) message.parentMessageId else message.messageId

    /** The reply count to show under [message]: its thread's replies when it is a root message, 0 for a reply. */
    fun replyCount(message: BaseMessage): Int =
        if (message.parentMessageId == 0L) message.threadInfo.replyCount else 0

    /** Loads up to [limit] replies of [root], oldest first. [onResult] always gets a list (empty on an error). */
    fun loadReplies(root: BaseMessage, limit: Int = 100, onResult: (List<BaseMessage>, SendbirdException?) -> Unit) {
        val params = ThreadMessageListParams().apply {
            previousResultSize = 0
            nextResultSize = limit
        }
        root.getThreadedMessagesByTimestamp(root.createdAt, params) { _, replies, e ->
            onResult(replies.orEmpty(), e)
        }
    }

    /** Sends [text] as a reply in the thread of [message]. Show the returned pending message right away. */
    fun reply(channel: GroupChannel, message: BaseMessage, text: String, onResult: (UserMessage?, SendbirdException?) -> Unit): UserMessage? {
        val params = UserMessageCreateParams(text).apply { parentMessageId = rootId(message) }
        return channel.sendUserMessage(params) { sent, e -> onResult(sent, e) }
    }
}

/**
 * Live updates for an open thread screen: new replies to [rootMessageId] and reply-count changes for any parent in the
 * channel. Call [start] in onCreate (or onStart) and [stop] in onDestroy (or onStop).
 */
class ThreadReplyListener(
    private val channelUrl: String,
    private val rootMessageId: Long,
    private val onReply: (BaseMessage) -> Unit,
    private val onThreadInfo: (ThreadInfoUpdateEvent) -> Unit = {},
) {
    private val handlerId = "thread-$channelUrl-$rootMessageId"

    fun start() {
        SendbirdChat.addChannelHandler(handlerId, object : GroupChannelHandler() {
            override fun onMessageReceived(channel: BaseChannel, message: BaseMessage) {
                if (channel.url == channelUrl && message.parentMessageId == rootMessageId) onReply(message)
            }

            override fun onThreadInfoUpdated(channel: BaseChannel, threadInfoUpdateEvent: ThreadInfoUpdateEvent) {
                // the parent whose messageId == threadInfoUpdateEvent.targetMessageId takes it with applyThreadInfoUpdateEvent
                if (channel.url == channelUrl) onThreadInfo(threadInfoUpdateEvent)
            }
        })
    }

    fun stop() {
        SendbirdChat.removeChannelHandler(handlerId)
    }
}
