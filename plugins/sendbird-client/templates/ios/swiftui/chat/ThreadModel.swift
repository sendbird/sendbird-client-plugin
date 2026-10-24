// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/create-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/using-message-threading/list-replies-in-a-message-thread
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseMessage.html (getThreadedMessages, parentMessageId, createdAt)
// source: knowledge/curated/ios/products/chat.md ("Message threads")
// The SDK calls are the ones in the UIKit-host template templates/ios/uikit/chat/MessageThreads.swift, verified against
// the 4.39.11 release .swiftinterface (ThreadedMessageListHandler gives an optional array, hence `?? []`). This file only
// wraps them in an ObservableObject; the wrapper is standard SwiftUI/Combine, not an SDK API. Compiled by
// tools/templates/compile-check-ios.sh against the pinned and latest SPM releases. Delegate callbacks may arrive off
// the main thread, so they are `nonisolated` and hop to the main actor.

import Foundation
import Combine
import SendbirdChatSDK

/// One thread screen: the replies of a root message, sending a reply, and new replies as they arrive.
/// Hold it as a `@StateObject`, call `start()` in `.onAppear`, and `stop()` when the thread screen is dismissed.
@MainActor
final class ThreadModel: NSObject, ObservableObject, GroupChannelDelegate {
    @Published private(set) var replies: [BaseMessage] = []
    @Published private(set) var lastError: String?

    private let channel: GroupChannel
    private let rootMessage: BaseMessage
    private let rootMessageId: Int64
    private let channelURL: String
    private let identifier: String

    /// `rootMessage` is the message the thread hangs on (parentMessageId == 0): replies are listed from its time on.
    init(channel: GroupChannel, rootMessage: BaseMessage) {
        self.channel = channel
        self.rootMessage = rootMessage
        self.rootMessageId = rootMessage.messageId
        self.channelURL = channel.channelURL
        self.identifier = "thread-\(channel.channelURL)-\(rootMessage.messageId)"
        super.init()
    }

    func start(limit: Int = 100) {
        SendbirdChat.addChannelDelegate(self, identifier: identifier)
        let params = ThreadedMessageListParams()
        params.previousResultSize = 0
        params.nextResultSize = limit
        rootMessage.getThreadedMessages(timestamp: rootMessage.createdAt, params: params) { [weak self] _, list, error in
            let loaded = list ?? []
            Task { @MainActor in
                loaded.forEach { self?.add($0) }
                if let error { self?.lastError = "loading replies failed: \(error)" }
            }
        }
    }

    func stop() { SendbirdChat.removeChannelDelegate(forIdentifier: identifier) }

    func reply(_ text: String) {
        let params = UserMessageCreateParams(message: text)
        params.parentMessageId = rootMessageId
        channel.sendUserMessage(params: params) { [weak self] sent, error in
            Task { @MainActor in
                if let sent { self?.add(sent) }
                if let error { self?.lastError = "reply failed: \(error)" }
            }
        }
    }

    private func add(_ message: BaseMessage) {
        guard !replies.contains(where: { $0.messageId == message.messageId }) else { return }
        replies.append(message)
        replies.sort { $0.createdAt < $1.createdAt }
    }

    nonisolated func channel(_ channel: BaseChannel, didReceive message: BaseMessage) {
        guard channel.channelURL == channelURL, message.parentMessageId == rootMessageId else { return }
        Task { @MainActor [weak self] in self?.add(message) }
    }
}
