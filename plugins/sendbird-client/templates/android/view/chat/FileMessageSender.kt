// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-base-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/sending-a-message/track-file-upload-progress-using-a-handler
// source: knowledge/curated/android/products/chat.md ("Upload progress")
// source: knowledge/curated/android/cross-cutting/pitfalls.md ("Messages (file send / resend)")
// Verified with javap on the sendbird-chat 4.36.4 and 4.36.5 AARs: BaseChannel sendFileMessage(FileMessageCreateParams,
// FileMessageWithProgressHandler), resendMessage(FileMessage, FileMessageWithProgressHandler), cancelFileMessageUpload(String);
// FileMessageCreateParams(File) with fileName/mimeType setters; FileMessageWithProgressHandler onProgress(Int, Int, Int) and
// onResult(FileMessage?, SendbirdException?); BaseMessage isResendable, requestId. Not used on purpose: the resendMessage and
// resendFileMessage overloads that take a File, which are deprecated (the SDK keeps the file it was sent with).
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.chat

import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.FileMessageWithProgressHandler
import com.sendbird.android.message.FileMessage
import com.sendbird.android.params.FileMessageCreateParams
import java.io.File

/**
 * Sends a picked image or file, reports upload progress (0..100), cancels an upload that is still running,
 * and resends a message that failed. Copy the picked content Uri into a File in cacheDir first.
 */
object FileMessageSender {
    /**
     * Returns the pending message; keep it for [cancel] until [onResult] runs.
     * [onResult] gets the sent message and null, or the failed message and the error (offer [resend] for it).
     */
    fun send(
        channel: GroupChannel,
        file: File,
        mimeType: String,
        onProgress: (Int) -> Unit,
        onResult: (FileMessage?, SendbirdException?) -> Unit,
    ): FileMessage? {
        val params = FileMessageCreateParams(file).apply {
            fileName = file.name
            this.mimeType = mimeType
        }
        return channel.sendFileMessage(params, progressHandler(onProgress, onResult))
    }

    /** Cancels an upload that has not finished, by the pending message's request ID. */
    fun cancel(channel: GroupChannel, pending: FileMessage): Boolean =
        channel.cancelFileMessageUpload(pending.requestId)

    /** Resends a failed file message with the file it was first sent with. */
    fun resend(
        channel: GroupChannel,
        failed: FileMessage,
        onProgress: (Int) -> Unit,
        onResult: (FileMessage?, SendbirdException?) -> Unit,
    ): FileMessage? {
        if (!failed.isResendable) return null
        return channel.resendMessage(failed, progressHandler(onProgress, onResult))
    }

    private fun progressHandler(
        onProgress: (Int) -> Unit,
        onResult: (FileMessage?, SendbirdException?) -> Unit,
    ) = object : FileMessageWithProgressHandler {
        override fun onProgress(bytesSent: Int, totalBytesSent: Int, totalBytesToSend: Int) {
            if (totalBytesToSend > 0) onProgress((totalBytesSent.toLong() * 100 / totalBytesToSend).toInt())
        }

        override fun onResult(message: FileMessage?, e: SendbirdException?) = onResult(message, e)
    }
}
