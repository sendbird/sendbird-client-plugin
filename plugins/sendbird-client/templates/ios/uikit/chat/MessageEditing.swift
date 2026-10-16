// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html (updateUserMessage, deleteMessage, channelURL)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (getCurrentUser, addChannelDelegate, removeChannelDelegate)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-a-message/update-a-message
// source: knowledge/curated/ios/products/chat.md ("Update and delete a message")
// Verified against the 4.39.10 and 4.39.11 release .swiftinterface (extension BaseChannel:
// updateUserMessage(messageId:params:completionHandler:), deleteMessage(_:completionHandler:);
// UserMessageUpdateParams init(message:); BaseMessage sender, messageId; SendbirdChat getCurrentUser(),
// addChannelDelegate(_:identifier:), removeChannelDelegate(forIdentifier:); BaseChannelDelegate optional
// channel(_:didUpdate:) and channel(_:messageWasDeleted:)). Compiled by tools/templates/compile-check-ios.sh
// against the pinned and latest SPM releases.
// A user can update or delete messages they sent; channel operators can update or delete any message.

import Foundation
import SendbirdChatSDK

/// Edit and delete actions for the message list's long-press menu.
enum MessageEditor {
    /// True when the connected user sent `message`; show Edit and Delete only for those.
    static func isMine(_ message: BaseMessage) -> Bool {
        guard let me = SendbirdChat.getCurrentUser(), let sender = message.sender else { return false }
        return sender.userId == me.userId
    }

    /// Replaces the text of a user message. `completion` gets the updated message to put in the list.
    static func edit(
        _ message: UserMessage,
        newText: String,
        in channel: GroupChannel,
        completion: @escaping (UserMessage?, SBError?) -> Void
    ) {
        let params = UserMessageUpdateParams(message: newText)
        channel.updateUserMessage(messageId: message.messageId, params: params) { updated, error in
            completion(updated, error)
        }
    }

    /// Deletes a message for everyone in the channel. Remove the row when `completion` gets nil.
    static func delete(_ message: BaseMessage, in channel: GroupChannel, completion: @escaping (SBError?) -> Void) {
        channel.deleteMessage(message) { error in
            completion(error)
        }
    }
}

/// Tells one open conversation screen that another member edited or deleted a message.
/// An app that already shows messages through a MessageCollection gets these changes from its
/// collection delegate instead and does not need this observer.
final class MessageChangeObserver: NSObject, GroupChannelDelegate {
    private let channelURL: String
    private let identifier: String
    private let onUpdated: (BaseMessage) -> Void
    private let onDeleted: (Int64) -> Void

    init(channelURL: String, onUpdated: @escaping (BaseMessage) -> Void, onDeleted: @escaping (Int64) -> Void) {
        self.channelURL = channelURL
        self.identifier = "message-changes-\(channelURL)"
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        super.init()
    }

    /// Call in viewDidLoad; call `stop()` when the screen goes away.
    func start() { SendbirdChat.addChannelDelegate(self, identifier: identifier) }
    func stop() { SendbirdChat.removeChannelDelegate(forIdentifier: identifier) }

    func channel(_ channel: BaseChannel, didUpdate message: BaseMessage) {
        guard channel.channelURL == channelURL else { return }
        onUpdated(message)
    }

    func channel(_ channel: BaseChannel, messageWasDeleted messageId: Int64) {
        guard channel.channelURL == channelURL else { return }
        onDeleted(messageId)
    }
}
