// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (getTotalUnreadMessageCount, addUserEventDelegate, removeUserEventDelegate)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html (unreadMessageCount, markAsRead)
// source: knowledge/curated/ios/products/chat.md ("Unread counts")
// The SDK calls are the ones in the UIKit-host template templates/ios/uikit/chat/UnreadCount.swift, verified against
// the 4.39.10 and 4.39.11 release .swiftinterface. This file only wraps them in an ObservableObject; the wrapper is
// standard SwiftUI/Combine, not an SDK API. Compiled by tools/templates/compile-check-ios.sh against the pinned and
// latest SPM releases. Delegate callbacks may arrive off the main thread, so they are `nonisolated` and hop to the
// main actor.

import Foundation
import Combine
import SendbirdChatSDK

/// The total unread message count for a tab badge, e.g. `.badge(unread.total)`.
/// Start it after connect (next to `ChatSession.shared.connect`) and stop it on sign-out.
@MainActor
final class UnreadCountModel: NSObject, ObservableObject, UserEventDelegate {
    /// One model for the whole app, so the badge and every screen read the same number.
    static let shared = UnreadCountModel()

    @Published private(set) var total = 0

    private let identifier = "unread-count-model"

    func start() {
        SendbirdChat.addUserEventDelegate(self, identifier: identifier)
        refresh()
    }

    func stop() {
        SendbirdChat.removeUserEventDelegate(forIdentifier: identifier)
        total = 0
    }

    /// Fetches the total from the server. The docs say the live event below (or its per-custom-type part) can be
    /// turned off for an app, so also call this when a screen appears and after `markRead(_:)`.
    func refresh() {
        SendbirdChat.getTotalUnreadMessageCount { [weak self] count, error in
            guard error == nil else { return }
            Task { @MainActor in self?.total = Int(count) }
        }
    }

    /// Resets one channel's count when the user opens it, then refreshes the total.
    func markRead(_ channel: GroupChannel) {
        channel.markAsRead { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor in self?.refresh() }
        }
    }

    /// The badge for one row of the channel list.
    func unreadCount(of channel: GroupChannel) -> Int {
        Int(channel.unreadMessageCount)
    }

    nonisolated func didUpdateTotalUnreadMessageCount(unreadMessageCount: UnreadMessageCount) {
        let count = unreadMessageCount.groupChannelCount
        Task { @MainActor [weak self] in self?.total = count }
    }
}
