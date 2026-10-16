// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html (sendFileMessage, resendFileMessage, cancelUploadingFileMessage)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/sending-a-message/track-file-upload-progress-using-a-handler
// source: knowledge/curated/ios/products/chat.md ("Upload progress and resending a failed file message")
// The SDK calls are the ones in the UIKit-host template templates/ios/uikit/chat/FileMessageSender.swift, verified
// against the 4.39.10 and 4.39.11 release .swiftinterface. This file only wraps them in an ObservableObject so a
// SwiftUI view can show progress and a retry button; the wrapper is standard SwiftUI/Combine, not an SDK API.
// Compiled by tools/templates/compile-check-ios.sh against the pinned and latest SPM releases.

import Foundation
import Combine
import SendbirdChatSDK

/// Upload state for one conversation: progress while a file is sending, and the failed message to retry.
/// Create it with the conversation's channel, e.g. `@StateObject var upload = FileUploadModel(channel: channel)`.
@MainActor
final class FileUploadModel: ObservableObject {
    /// 0.0...1.0 while an upload runs, nil otherwise.
    @Published private(set) var progress: Double?
    /// The last message that failed to send; show a retry button while it is set.
    @Published private(set) var failedMessage: FileMessage?
    @Published private(set) var lastError: String?

    private let channel: GroupChannel
    private var pending: FileMessage?
    private var lastData: Data?

    init(channel: GroupChannel) {
        self.channel = channel
    }

    /// Sends picked image or file bytes, e.g. from PhotosPicker's `loadTransferable(type: Data.self)`.
    func send(_ data: Data, fileName: String, mimeType: String) {
        let params = FileMessageCreateParams(file: data)
        params.fileName = fileName
        params.mimeType = mimeType
        lastData = data
        progress = 0
        failedMessage = nil
        pending = channel.sendFileMessage(params: params, progressHandler: { [weak self] _, _, sent, total in
            guard total > 0 else { return }
            let fraction = Double(sent) / Double(total)
            Task { @MainActor in self?.progress = fraction }
        }, completionHandler: { [weak self] message, error in
            Task { @MainActor in self?.finish(message, error) }
        })
    }

    /// Cancels the upload that is running.
    func cancel() {
        guard let pending else { return }
        BaseChannel.cancelUploadingFileMessage(requestId: pending.requestId) { _, _ in }
    }

    /// Resends `failedMessage` with the bytes of the last `send`.
    func retry() {
        guard let failed = failedMessage, failed.isResendable(in: channel) else { return }
        progress = 0
        failedMessage = nil
        channel.resendFileMessage(failed, binaryData: lastData, progressHandler: { [weak self] _, _, sent, total in
            guard total > 0 else { return }
            let fraction = Double(sent) / Double(total)
            Task { @MainActor in self?.progress = fraction }
        }, completionHandler: { [weak self] message, error in
            Task { @MainActor in self?.finish(message, error) }
        })
    }

    private func finish(_ message: FileMessage?, _ error: SBError?) {
        progress = nil
        pending = nil
        if let error {
            failedMessage = message
            lastError = "file send failed: \(error)"
        } else {
            lastData = nil
            lastError = nil
        }
    }
}
