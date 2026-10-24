// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/create-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/list-replies-in-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseMessage.html (getThreadedMessages, parentMessageId, createdAt)
// source: knowledge/curated/ios/products/chat.md ("Message threads")
// Verified against the 4.39.11 release .swiftinterface: extension BaseMessage getThreadedMessages(timestamp:params:
// completionHandler:) 952 and apply(_: ThreadInfoUpdateEvent) 947; ThreadedMessageListHandler 3629 =
// (parentMessage: BaseMessage?, messages: [BaseMessage]?, error: SBError?); ThreadedMessageListParams 6858 with
// previousResultSize, nextResultSize, includeParentMessageInfo; BaseMessageCreateParams.parentMessageId 1226;
// UserMessageCreateParams init(message:); BaseChannel sendUserMessage(params:completionHandler:) 495; SendbirdChat
// addChannelDelegate(_:identifier:) 6376, removeChannelDelegate(forIdentifier:) 6377; BaseChannelDelegate optional
// channel(_:didReceive:) and channel(_:didUpdateThreadInfo:) 900. Compiled by tools/templates/compile-check-ios.sh
// against the pinned and latest SPM releases.
// A thread screen is a UIViewController: never name its root-message property `parent`, which is UIViewController's
// own `parent` (2026-10-24: `private let parent: BaseMessage` did not build). This file says `rootMessage`.
// BaseMessage.threadInfo (1039) is a non-optional ThreadInfo (6841, replyCount 6842): `if let info = message.threadInfo`
// does not build ("initializer for conditional binding must have Optional type"; 2026-10-24), so replyCount(of:) reads it
// directly.

import Foundation
import SendbirdChatSDK

/// Replies in a message thread. Threads are one level deep: every reply points at the thread's root message.
enum MessageThreads {
    /// The ID a reply must carry: the root message's ID, also when the user replies to a reply.
    static func rootId(of message: BaseMessage) -> Int64 {
        message.parentMessageId != 0 ? message.parentMessageId : message.messageId
    }

    /// The reply count to show under `message`: its thread's replies when it is a root message, 0 for a reply.
    static func replyCount(of message: BaseMessage) -> Int {
        message.parentMessageId == 0 ? message.threadInfo.replyCount : 0
    }

    /// Loads up to `limit` replies of `rootMessage`, oldest first. `completion` always gets an array (empty on an error).
    static func loadReplies(of rootMessage: BaseMessage, limit: Int = 100, completion: @escaping ([BaseMessage], SBError?) -> Void) {
        let params = ThreadedMessageListParams()
        params.previousResultSize = 0
        params.nextResultSize = limit
        params.includeParentMessageInfo = true
        rootMessage.getThreadedMessages(timestamp: rootMessage.createdAt, params: params) { _, replies, error in
            completion(replies ?? [], error)
        }
    }

    /// Sends `text` as a reply in the thread of `message`. Show the returned pending message right away.
    @discardableResult
    static func reply(to message: BaseMessage, text: String, in channel: GroupChannel, completion: @escaping (UserMessage?, SBError?) -> Void) -> UserMessage {
        let params = UserMessageCreateParams(message: text)
        params.parentMessageId = rootId(of: message)
        return channel.sendUserMessage(params: params) { sent, error in
            completion(sent, error)
        }
    }
}

/// Live updates for an open thread screen: new replies to the root message, and reply-count changes for any parent
/// in the channel. Keep it in the thread view controller; call `start()` in viewDidLoad and `stop()` when the
/// screen goes away.
final class ThreadReplyObserver: NSObject, GroupChannelDelegate {
    private let channelURL: String
    private let rootMessageId: Int64
    private let identifier: String
    private let onReply: (BaseMessage) -> Void
    private let onThreadInfo: (ThreadInfoUpdateEvent) -> Void

    init(channelURL: String, rootMessageId: Int64, onReply: @escaping (BaseMessage) -> Void,
         onThreadInfo: @escaping (ThreadInfoUpdateEvent) -> Void = { _ in }) {
        self.channelURL = channelURL
        self.rootMessageId = rootMessageId
        self.identifier = "thread-\(channelURL)-\(rootMessageId)"
        self.onReply = onReply
        self.onThreadInfo = onThreadInfo
        super.init()
    }

    func start() { SendbirdChat.addChannelDelegate(self, identifier: identifier) }
    func stop() { SendbirdChat.removeChannelDelegate(forIdentifier: identifier) }

    func channel(_ channel: BaseChannel, didReceive message: BaseMessage) {
        guard channel.channelURL == channelURL, message.parentMessageId == rootMessageId else { return }
        onReply(message)
    }

    func channel(_ channel: BaseChannel, didUpdateThreadInfo threadInfoUpdateEvent: ThreadInfoUpdateEvent) {
        // the parent whose messageId == threadInfoUpdateEvent.targetMessageId takes it with apply(_:)
        guard channel.channelURL == channelURL else { return }
        onThreadInfo(threadInfoUpdateEvent)
    }
}
