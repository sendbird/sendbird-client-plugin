// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/GroupChannel.html (startTyping, endTyping, getTypingUsers, getUnreadMemberCount, markAsRead)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html (addChannelDelegate, removeChannelDelegate)
// source: knowledge/curated/ios/products/chat.md ("Typing indicator (group channels)", "Read receipts for a message")
// The SDK calls are the ones in the UIKit-host template templates/ios/uikit/chat/TypingAndReadReceipts.swift,
// verified against the 4.39.10 and 4.39.11 release .swiftinterface. This file only wraps them in an
// ObservableObject; the wrapper is standard SwiftUI/Combine, not an SDK API. Compiled by
// tools/templates/compile-check-ios.sh against the pinned and latest SPM releases. Delegate callbacks may arrive
// off the main thread, so they are `nonisolated` and hop to the main actor.

import Foundation
import Combine
import SendbirdChatSDK

/// "Alice is typing…" and read marks for one conversation screen.
@MainActor
final class ChannelActivityModel: NSObject, ObservableObject, GroupChannelDelegate {
    /// Nicknames of the users typing now.
    @Published private(set) var typingNames: [String] = []
    /// Goes up each time another member reads messages; views that show read marks read it so they redraw.
    @Published private(set) var readReceiptsVersion = 0

    private let channel: GroupChannel
    private let channelURL: String
    private let identifier: String

    init(channel: GroupChannel) {
        self.channel = channel
        self.channelURL = channel.channelURL
        self.identifier = "channel-activity-model-\(channel.channelURL)"
        super.init()
    }

    /// Call in `.onAppear`; call `stop()` in `.onDisappear` of the conversation screen.
    func start() {
        SendbirdChat.addChannelDelegate(self, identifier: identifier)
        channel.markAsRead(completionHandler: nil)
    }

    func stop() {
        channel.endTyping()
        SendbirdChat.removeChannelDelegate(forIdentifier: identifier)
    }

    /// Call from the text field: `.onChange(of: draft) { activity.textDidChange($0) }`. Call `sent()` after sending.
    func textDidChange(_ text: String) {
        if text.isEmpty { channel.endTyping() } else { channel.startTyping() }
    }

    func sent() { channel.endTyping() }

    /// Call when a new message arrives while the conversation is on screen.
    func markRead() { channel.markAsRead(completionHandler: nil) }

    /// How many members have not read `message`; 0 means everyone has. Read `readReceiptsVersion` in the same view.
    func unreadMemberCount(of message: BaseMessage) -> Int {
        channel.getUnreadMemberCount(message)
    }

    nonisolated func channelDidUpdateTypingStatus(_ channel: GroupChannel) {
        guard channel.channelURL == channelURL else { return }
        let names = (channel.getTypingUsers() ?? []).map { $0.nickname }
        Task { @MainActor [weak self] in self?.typingNames = names }
    }

    nonisolated func channel(_ channel: GroupChannel, userDidMarkAsRead userIds: [String]) {
        guard channel.channelURL == channelURL else { return }
        Task { @MainActor [weak self] in self?.readReceiptsVersion += 1 }
    }
}
