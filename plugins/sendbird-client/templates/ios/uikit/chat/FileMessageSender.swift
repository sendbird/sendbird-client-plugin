// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/BaseChannel.html (sendFileMessage, resendFileMessage, cancelUploadingFileMessage)
// source: https://sendbird.com/docs/chat/sdk/v4/ios/message/sending-a-message/track-file-upload-progress-using-a-handler
// source: knowledge/curated/ios/products/chat.md ("Upload progress and resending a failed file message")
// Verified against the 4.39.10 and 4.39.11 release .swiftinterface (extension BaseChannel:
// sendFileMessage(params:progressHandler:completionHandler:), resendFileMessage(_:binaryData:progressHandler:completionHandler:),
// class func cancelUploadingFileMessage(requestId:completionHandler:); FileMessageCreateParams init(file:), fileName, mimeType;
// BaseMessage isResendable(in:) — the no-argument isResendable() is deprecated). Compiled by
// tools/templates/compile-check-ios.sh against the pinned and latest SPM releases.
// SPM: https://github.com/sendbird/sendbird-chat-sdk-ios , product SendbirdChatSDK.

import Foundation
import SendbirdChatSDK

/// Sends an image or any file to a channel, reports upload progress, cancels an upload that is still
/// running, and resends a message that failed.
enum FileMessageSender {
    /// Sends `data` as a file message. `onProgress` gets 0.0...1.0. The returned pending message carries the
    /// `requestId` that `cancel(_:)` needs; keep it (and `data`) until `completion` runs.
    /// `completion` gets the sent message, or the failed message plus the error (offer `resend` for it).
    @discardableResult
    static func send(
        _ data: Data,
        fileName: String,
        mimeType: String,
        in channel: GroupChannel,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (FileMessage?, SBError?) -> Void
    ) -> FileMessage? {
        let params = FileMessageCreateParams(file: data)
        params.fileName = fileName
        params.mimeType = mimeType
        return channel.sendFileMessage(params: params, progressHandler: { _, _, totalBytesSent, totalBytesExpectedToSend in
            guard totalBytesExpectedToSend > 0 else { return }
            onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
        }, completionHandler: { message, error in
            completion(message, error)
        })
    }

    /// Cancels an upload that has not finished yet (a class method on BaseChannel, keyed by the request ID).
    static func cancel(_ pending: FileMessage) {
        BaseChannel.cancelUploadingFileMessage(requestId: pending.requestId) { _, _ in }
    }

    /// Resends a failed file message. Pass the original bytes: when the upload itself failed the SDK
    /// uploads them again; when only the send failed it reuses the uploaded file and ignores them.
    /// Returns false (and does nothing) when the SDK says the message cannot be resent.
    @discardableResult
    static func resend(
        _ failed: FileMessage,
        originalData: Data?,
        in channel: GroupChannel,
        onProgress: @escaping (Double) -> Void,
        completion: @escaping (FileMessage?, SBError?) -> Void
    ) -> Bool {
        guard failed.isResendable(in: channel) else { return false }
        channel.resendFileMessage(failed, binaryData: originalData, progressHandler: { _, _, totalBytesSent, totalBytesExpectedToSend in
            guard totalBytesExpectedToSend > 0 else { return }
            onProgress(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
        }, completionHandler: { message, error in
            completion(message, error)
        })
        return true
    }
}
