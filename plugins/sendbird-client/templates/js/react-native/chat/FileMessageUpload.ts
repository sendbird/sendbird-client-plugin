// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html (sendFileMessage, resendMessage)
// source: knowledge/curated/js/products/chat.md ("Send a file message")
// Verified against the @sendbird/chat 4.22.11 and 4.22.14 type declarations (lib/__definition.d.ts): BaseChannel
// sendFileMessage(FileMessageCreateParams): MessageRequestHandler, resendMessage(FileMessage, FileCompat?); FileCompat is
// File | Blob | FileInfo, and FileInfo ({ name, uri, type }) is the React Native file shape; MessageRequestHandler
// onPending/onFailed/onSucceeded; SendableMessage isResendable. Not used on purpose: resendFileMessage, deprecated since
// v4.9.8. Type-checked by tools/templates/compile-check-js.sh against the pinned and latest packages.
//
// No upload progress here: sendFileMessage reports none, and uploadFile (the progress path on the web) takes File | Blob,
// not the React Native FileInfo. Show the pending message (onPending) with a spinner instead.

import type { GroupChannel } from '@sendbird/chat/groupChannel';
import type { BaseMessage, FileInfo, FileMessage } from '@sendbird/chat/message';

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

/**
 * Sends a picked image or document. `file` is what the picker returns, mapped to { uri, name, type }
 * (e.g. an image picker asset's uri, fileName, and type).
 */
export function sendFile(channel: GroupChannel, file: FileInfo, callbacks: FileSendCallbacks) {
  return channel
    .sendFileMessage({ file, fileName: file.name, mimeType: file.type })
    .onPending((message) => callbacks.onPending?.(asFile(message)))
    .onFailed((error, message) => callbacks.onFailed(error, message ? asFile(message) : null))
    .onSucceeded((message) => callbacks.onSucceeded(asFile(message)));
}

/** Resends a failed file message. `file` is optional in the SDK; pass the original FileInfo when you still have it. */
export function resendFailedFile(channel: GroupChannel, failed: FileMessage, callbacks: FileSendCallbacks, file?: FileInfo) {
  if (!failed.isResendable) return null;
  return channel
    .resendMessage(failed, file)
    .onPending((message) => callbacks.onPending?.(message))
    .onFailed((error, message) => callbacks.onFailed(error, message))
    .onSucceeded((message) => callbacks.onSucceeded(message));
}
