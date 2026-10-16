// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html (sendFileMessage, uploadFile, resendMessage, cancelUploadingFileMessage)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/message/sending-a-message/track-file-upload-progress-using-a-handler
// source: knowledge/curated/js/products/chat.md ("Send a file message")
// Verified against the @sendbird/chat 4.22.11 and 4.22.14 type declarations (lib/__definition.d.ts): BaseChannel
// sendFileMessage(FileMessageCreateParams): MessageRequestHandler, uploadFile(FileUploadParams): Promise<FileUploadResult>
// (uploadStartedHandler, progressHandler), resendMessage(FileMessage, FileCompat?), cancelUploadingFileMessage(requestId);
// MessageRequestHandler onPending/onFailed/onSucceeded; SendableMessage isResendable. Not used on purpose: resendFileMessage,
// deprecated since v4.9.8. Type-checked by tools/templates/compile-check-js.sh against the pinned and latest packages.
//
// sendFileMessage itself reports no progress. The docs' way to show progress is to upload with uploadFile (progressHandler),
// then send the returned URL as fileUrl.

import type { GroupChannel } from '@sendbird/chat/groupChannel';
import type { BaseMessage, FileMessage } from '@sendbird/chat/message';

export interface FileSendCallbacks {
  /** The pending message (messageId 0) to show in the list right away. */
  onPending?: (message: FileMessage) => void;
  onSucceeded: (message: FileMessage) => void;
  /** Keep `message` (when present) and offer resendFailedFile for it. */
  onFailed: (error: Error, message: FileMessage | null) => void;
}

// sendFileMessage's handler is typed with the SDK's (unexported) sendable base class; for file params the SDK
// gives FileMessage instances.
const asFile = (message: BaseMessage) => message as FileMessage;

/** Sends a picked File (e.g. from <input type="file">) as a file message. */
export function sendFile(channel: GroupChannel, file: File, callbacks: FileSendCallbacks) {
  return channel
    .sendFileMessage({ file, fileName: file.name, fileSize: file.size, mimeType: file.type })
    .onPending((message) => callbacks.onPending?.(asFile(message)))
    .onFailed((error, message) => callbacks.onFailed(error, message ? asFile(message) : null))
    .onSucceeded((message) => callbacks.onSucceeded(asFile(message)));
}

/**
 * Uploads first with a progress bar (0..100), then sends the uploaded file's URL as a file message.
 * `onUploadStarted` gives the request ID for cancelUpload (the SDK types describe that ID as the one to
 * cancel with). The returned promise rejects when uploadFile rejects; no message exists yet at that point.
 */
export async function sendFileWithProgress(
  channel: GroupChannel,
  file: File,
  callbacks: FileSendCallbacks & {
    onProgress: (percent: number) => void;
    onUploadStarted?: (requestId: string) => void;
  },
) {
  const { url } = await channel.uploadFile({
    file,
    uploadStartedHandler: (requestId: string) => callbacks.onUploadStarted?.(requestId),
    progressHandler: (_requestId: string, progress: number, total: number) => {
      if (total > 0) callbacks.onProgress(Math.round((progress / total) * 100));
    },
  });
  return channel
    .sendFileMessage({ fileUrl: url, fileName: file.name, fileSize: file.size, mimeType: file.type })
    .onPending((message) => callbacks.onPending?.(asFile(message)))
    .onFailed((error, message) => callbacks.onFailed(error, message ? asFile(message) : null))
    .onSucceeded((message) => callbacks.onSucceeded(asFile(message)));
}

/** Cancels an upload that is still running (request ID from onUploadStarted). */
export function cancelUpload(channel: GroupChannel, requestId: string) {
  return channel.cancelUploadingFileMessage(requestId);
}

/** Resends a failed file message. `file` is optional in the SDK; pass the original File when you still have it. */
export function resendFailedFile(channel: GroupChannel, failed: FileMessage, callbacks: FileSendCallbacks, file?: File) {
  if (!failed.isResendable) return null;
  return channel
    .resendMessage(failed, file)
    .onPending((message) => callbacks.onPending?.(message))
    .onFailed((error, message) => callbacks.onFailed(error, message))
    .onSucceeded((message) => callbacks.onSucceeded(message));
}
