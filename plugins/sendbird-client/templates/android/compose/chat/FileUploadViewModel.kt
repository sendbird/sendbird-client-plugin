// source: https://sendbird.com/docs/chat/sdk/v4/android/ref/-sendbird-chat/com.sendbird.android.channel/-base-channel/index.html
// source: https://sendbird.com/docs/chat/sdk/v4/android/message/sending-a-message/track-file-upload-progress-using-a-handler
// source: knowledge/curated/android/products/chat.md ("Upload progress")
// source: knowledge/curated/android/cross-cutting/pitfalls.md ("Messages (file send / resend)")
// SDK calls (sendFileMessage with FileMessageWithProgressHandler, resendMessage, cancelFileMessageUpload) are the ones in the
// View-host template templates/android/view/chat/FileMessageSender.kt, verified with javap on the sendbird-chat 4.36.4 and
// 4.36.5 AARs. This file only wraps them in a ViewModel with a StateFlow so Compose can show progress and a retry button;
// the wrapper is standard AndroidX/coroutines/Compose, not an SDK API.
// Compiled by tools/templates/compile-check-android.sh against the pinned and latest SDK set.
package com.sendbird.client.templatecheck.compose.chat

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import com.sendbird.android.channel.GroupChannel
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.FileMessageWithProgressHandler
import com.sendbird.android.message.FileMessage
import com.sendbird.android.params.FileMessageCreateParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File

data class FileUploadState(
    /** 0..100 while an upload runs, null otherwise. */
    val progress: Int? = null,
    /** The last message that failed to send; show a retry button while it is set. */
    val failed: FileMessage? = null,
    val error: String? = null,
)

/** Upload state for one conversation. Copy the picked content Uri into a File in cacheDir before [send]. */
class FileUploadViewModel : ViewModel() {
    private val _state = MutableStateFlow(FileUploadState())
    val state: StateFlow<FileUploadState> = _state.asStateFlow()
    private var pending: FileMessage? = null

    fun send(channel: GroupChannel, file: File, mimeType: String) {
        val params = FileMessageCreateParams(file).apply {
            fileName = file.name
            this.mimeType = mimeType
        }
        _state.value = FileUploadState(progress = 0)
        pending = channel.sendFileMessage(params, handler())
    }

    /** Cancels the upload that is running. */
    fun cancel(channel: GroupChannel) {
        pending?.let { channel.cancelFileMessageUpload(it.requestId) }
    }

    /** Resends the failed message with the file it was first sent with. */
    fun retry(channel: GroupChannel) {
        val failed = _state.value.failed ?: return
        if (!failed.isResendable) return
        _state.value = FileUploadState(progress = 0)
        pending = channel.resendMessage(failed, handler())
    }

    private fun handler() = object : FileMessageWithProgressHandler {
        override fun onProgress(bytesSent: Int, totalBytesSent: Int, totalBytesToSend: Int) {
            if (totalBytesToSend > 0) {
                _state.value = _state.value.copy(progress = (totalBytesSent.toLong() * 100 / totalBytesToSend).toInt())
            }
        }

        override fun onResult(message: FileMessage?, e: SendbirdException?) {
            pending = null
            _state.value = if (e == null) FileUploadState() else FileUploadState(failed = message, error = e.message)
        }
    }
}

/** Progress bar while uploading, and a Retry button after a failure. */
@Composable
fun FileUploadStatus(vm: FileUploadViewModel, channel: GroupChannel) {
    val state by vm.state.collectAsState()
    Column {
        state.progress?.let { percent -> LinearProgressIndicator(progress = { percent / 100f }) }
        if (state.failed != null) {
            Text("Could not send the file.")
            Button(onClick = { vm.retry(channel) }) { Text("Retry") }
        }
    }
}
