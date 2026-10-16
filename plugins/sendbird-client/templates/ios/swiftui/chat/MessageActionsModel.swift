// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html (updateUserMessage, deleteMessage, channelURL)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (getCurrentUser, addChannelDelegate, removeChannelDelegate)
// source: knowledge/curated/ios/products/chat.md ("Update and delete a message")
// The SDK calls are the ones in the UIKit-host template templates/ios/uikit/chat/MessageEditing.swift, verified
// against the 4.39.10 and 4.39.11 release .swiftinterface. This file only wraps them in an ObservableObject; the
// wrapper is standard SwiftUI/Combine, not an SDK API. Compiled by tools/templates/compile-check-ios.sh against the
// pinned and latest SPM releases. Delegate callbacks may arrive off the main thread, so they are `nonisolated`
// and hop to the main actor.

import Foundation
import Combine
import SendbirdChatSDK

/// An edit or delete that happened in the open conversation (by this user or another member).
enum MessageChange {
    case updated(BaseMessage)
    case deleted(messageId: Int64)
}

/// Edit and delete for one conversation, plus the edits and deletes other members make.
/// Read `changes` with `.onReceive(actions.changes) { change in ... }` and update the shown list.
/// An app that already shows messages through a MessageCollection gets other members' changes from the
/// collection and can skip `start()`.
@MainActor
final class MessageActionsModel: NSObject, ObservableObject, GroupChannelDelegate {
    let changes = PassthroughSubject<MessageChange, Never>()
    @Published private(set) var lastError: String?

    private let channel: GroupChannel
    private let channelURL: String
    private let identifier: String

    init(channel: GroupChannel) {
        self.channel = channel
        self.channelURL = channel.channelURL
        self.identifier = "message-actions-\(channel.channelURL)"
        super.init()
    }

    /// Call in `.onAppear`; call `stop()` in `.onDisappear` of the conversation screen.
    func start() { SendbirdChat.addChannelDelegate(self, identifier: identifier) }
    func stop() { SendbirdChat.removeChannelDelegate(forIdentifier: identifier) }

    /// True when the connected user sent `message`; offer Edit and Delete only for those.
    func isMine(_ message: BaseMessage) -> Bool {
        guard let me = SendbirdChat.getCurrentUser(), let sender = message.sender else { return false }
        return sender.userId == me.userId
    }

    func edit(_ message: UserMessage, newText: String) {
        let params = UserMessageUpdateParams(message: newText)
        channel.updateUserMessage(messageId: message.messageId, params: params) { [weak self] updated, error in
            Task { @MainActor in
                if let updated { self?.changes.send(.updated(updated)) }
                if let error { self?.lastError = "edit failed: \(error)" }
            }
        }
    }

    func delete(_ message: BaseMessage) {
        let messageId = message.messageId
        channel.deleteMessage(message) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = "delete failed: \(error)" } else { self?.changes.send(.deleted(messageId: messageId)) }
            }
        }
    }

    nonisolated func channel(_ channel: BaseChannel, didUpdate message: BaseMessage) {
        guard channel.channelURL == channelURL else { return }
        Task { @MainActor [weak self] in self?.changes.send(.updated(message)) }
    }

    nonisolated func channel(_ channel: BaseChannel, messageWasDeleted messageId: Int64) {
        guard channel.channelURL == channelURL else { return }
        Task { @MainActor [weak self] in self?.changes.send(.deleted(messageId: messageId)) }
    }
}
