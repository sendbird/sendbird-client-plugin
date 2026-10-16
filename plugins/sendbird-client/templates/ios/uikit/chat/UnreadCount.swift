// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (getTotalUnreadMessageCount, addUserEventDelegate, removeUserEventDelegate)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html (unreadMessageCount, markAsRead)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/event-delegate/managing-user-event-delegates/add-or-remove-a-user-event-delegate
// source: knowledge/curated/ios/products/chat.md ("Unread counts")
// Verified against the 4.39.10 and 4.39.11 release .swiftinterface (SendbirdChat static
// getTotalUnreadMessageCount(completionHandler:) with CountHandler, addUserEventDelegate(_:identifier:),
// removeUserEventDelegate(forIdentifier:); UserEventDelegate optional didUpdateTotalUnreadMessageCount(unreadMessageCount:);
// UnreadMessageCount groupChannelCount; GroupChannel unreadMessageCount, markAsRead(completionHandler:)).
// Not used on purpose: the deprecated SendbirdChat.add(_:identifier:) and getTotalUnreadMessageCount(params:completionHandler:),
// and the GroupChannel getTotalUnreadMessageCount overloads, which are unavailable. Compiled by
// tools/templates/compile-check-ios.sh against the pinned and latest SPM releases.

import Foundation
import SendbirdChatSDK

/// Keeps a tab or app badge in step with the total number of unread messages in the user's group channels.
/// Start it after connect and stop it on sign-out.
final class UnreadCountObserver: NSObject, UserEventDelegate {
    private let identifier = "unread-count-badge"
    private let onChange: (Int) -> Void

    init(onChange: @escaping (Int) -> Void) {
        self.onChange = onChange
        super.init()
    }

    func start() {
        SendbirdChat.addUserEventDelegate(self, identifier: identifier)
        refresh()
    }

    func stop() {
        SendbirdChat.removeUserEventDelegate(forIdentifier: identifier)
    }

    /// Fetches the total from the server. The docs say the live event below (or its per-custom-type part) can be
    /// turned off for an app, so also call this when the screen appears and after `markRead(_:)`.
    func refresh() {
        SendbirdChat.getTotalUnreadMessageCount { [weak self] count, error in
            guard error == nil else { return }
            self?.onChange(Int(count))
        }
    }

    func didUpdateTotalUnreadMessageCount(unreadMessageCount: UnreadMessageCount) {
        onChange(unreadMessageCount.groupChannelCount)
    }

    /// The badge for one row of the channel list.
    static func unreadCount(of channel: GroupChannel) -> Int {
        Int(channel.unreadMessageCount)
    }

    /// Marks every message in the channel as read (resets its count) when the user opens the conversation.
    func markRead(_ channel: GroupChannel) {
        channel.markAsRead { [weak self] error in
            guard error == nil else { return }
            self?.refresh()
        }
    }
}
