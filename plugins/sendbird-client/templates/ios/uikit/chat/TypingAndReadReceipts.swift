// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html (startTyping, endTyping, getTypingUsers, getUnreadMemberCount, getReadMembers, markAsRead)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (addChannelDelegate, removeChannelDelegate)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/managing-read-status-in-a-group-channel/get-read-status
// source: knowledge/curated/ios/products/chat.md ("Typing indicator (group channels)", "Read receipts for a message")
// Verified against the 4.39.10 and 4.39.11 release .swiftinterface (GroupChannel startTyping(), endTyping(),
// getTypingUsers(), getUnreadMemberCount(_:), getReadMembers(message:includeAllMembers:), markAsRead(completionHandler:);
// GroupChannelDelegate optional channelDidUpdateTypingStatus(_:) and channel(_:userDidMarkAsRead:)).
// Not used on purpose: channelDidUpdateReadStatus(_:) and channelDidUpdateReadStatus(_:userIds:), both deprecated
// (4.27.0 and 4.28.0). Compiled by tools/templates/compile-check-ios.sh against the pinned and latest SPM releases.

import Foundation
import SendbirdChatSDK

/// Typing indicator and read receipts for one open group channel screen.
final class ChannelActivityObserver: NSObject, GroupChannelDelegate {
    private let channelURL: String
    private let identifier: String
    private let onTypingChanged: ([User]) -> Void
    private let onReadReceiptsChanged: () -> Void

    /// `onTypingChanged` gets the users who are typing now (`getTypingUsers()`).
    /// `onReadReceiptsChanged` means another member read messages: redraw the read marks with `unreadMemberCount`.
    init(channelURL: String,
         onTypingChanged: @escaping ([User]) -> Void,
         onReadReceiptsChanged: @escaping () -> Void) {
        self.channelURL = channelURL
        self.identifier = "channel-activity-\(channelURL)"
        self.onTypingChanged = onTypingChanged
        self.onReadReceiptsChanged = onReadReceiptsChanged
        super.init()
    }

    /// Call in viewDidLoad; call `stop()` when the screen goes away.
    func start() { SendbirdChat.addChannelDelegate(self, identifier: identifier) }
    func stop() { SendbirdChat.removeChannelDelegate(forIdentifier: identifier) }

    func channelDidUpdateTypingStatus(_ channel: GroupChannel) {
        guard channel.channelURL == channelURL else { return }
        onTypingChanged(channel.getTypingUsers() ?? [])
    }

    func channel(_ channel: GroupChannel, userDidMarkAsRead userIds: [String]) {
        guard channel.channelURL == channelURL else { return }
        onReadReceiptsChanged()
    }

    // MARK: - Actions

    /// Call from the input's text-change handler: typing starts while there is text and ends when it is cleared.
    /// Also call `channel.endTyping()` right after sending.
    static func textDidChange(_ text: String, in channel: GroupChannel) {
        if text.isEmpty { channel.endTyping() } else { channel.startTyping() }
    }

    /// Call when the conversation is shown and when a new message arrives while it is on screen.
    static func markRead(_ channel: GroupChannel) {
        channel.markAsRead(completionHandler: nil)
    }

    /// How many members have not read `message` yet; 0 means everyone has read it.
    static func unreadMemberCount(of message: BaseMessage, in channel: GroupChannel) -> Int {
        channel.getUnreadMemberCount(message)
    }

    /// Members (other than the current user) who have read `message`.
    static func readers(of message: BaseMessage, in channel: GroupChannel) -> [Member] {
        channel.getReadMembers(message: message, includeAllMembers: false)
    }
}
