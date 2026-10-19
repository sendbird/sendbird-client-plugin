// source: @sendbird/chat 4.22.13 shipped type declarations (lib/__definition.d.ts,
// verified 2026-09-29) — GroupChannel.createMessageCollection, MessageCollection
// (initialize/onCacheResult/onApiResult/setMessageCollectionHandler/loadPrevious/
// loadNext/hasPrevious/hasNext), BaseChannel.addReaction/deleteReaction,
// GroupChannel.startTyping/endTyping/getTypingUsers/markAsRead,
// BaseMessage.messageId (:853), MessagePrototype.createdAt (:2823),
// SendableMessage.reqId (:4218), MessagePrototype.isUserMessage/isFileMessage/
// isMultipleFilesMessage/isAdminMessage (:2842/:2847/:2852/:2857), BaseMessage.message (:884),
// SendableMessage.sender (:4217), User.userId/nickname (:5182/:5185), GroupChannel.sendUserMessage
// (:2103), MessageRequestHandler onPending/onFailed/onSucceeded (:2882/:2889/:2896),
// FailedMessageHandler (:1627). Type-checked with `tsc --strict --skipLibCheck`
// against the real package.
// source: knowledge/curated/js/products/chat.md "List and receive messages" —
// the onCacheResult/onApiResult array order is not documented, so every batch is
// sorted by createdAt here instead of rendered as it arrives.
//
// A message-list screen: initial page (cache + API), live add/update/delete,
// pagination, plus reactions/typing/read-status helpers.

import type { GroupChannel, MessageEventContext } from '@sendbird/chat/groupChannel';
import { MessageCollectionInitPolicy, MessageFilter } from '@sendbird/chat/groupChannel';
import type { BaseMessage } from '@sendbird/chat/message';

export function createMessageListCollection(channel: GroupChannel, startingPoint = Date.now()) {
  return channel.createMessageCollection({
    filter: new MessageFilter(),
    startingPoint,
    limit: 30,
  });
}

// The request ID of a user, file, or multiple-files message ('' for an admin message).
// The type guards narrow to the message classes that have reqId; `'reqId' in message`
// does not, and leaves reqId typed unknown.
export function requestIdOf(message: BaseMessage): string {
  return message.isUserMessage() || message.isFileMessage() || message.isMultipleFilesMessage() ? message.reqId : '';
}

// A pending message and its sent copy share reqId; other messages match by messageId.
export function sameMessage(a: BaseMessage, b: BaseMessage): boolean {
  const ra = requestIdOf(a);
  const rb = requestIdOf(b);
  if (ra && rb) return ra === rb;
  return a.messageId === b.messageId;
}

// The React `key` for a message row. It follows sameMessage, so it stays the same when the
// sent copy replaces the pending one, and two messages sameMessage tells apart get different keys.
export function messageKey(message: BaseMessage): string {
  const reqId = requestIdOf(message);
  return reqId ? `req-${reqId}` : `id-${message.messageId}`;
}

// What one message row shows, with every field read through the declared types: the text is
// on every message, the sender only on user, file, and multiple-files messages (an admin
// message has none). Pass sb.currentUser?.userId as myUserId.
export function messageRow(message: BaseMessage, myUserId: string | undefined) {
  const sender =
    message.isUserMessage() || message.isFileMessage() || message.isMultipleFilesMessage() ? message.sender : null;
  return {
    key: messageKey(message),
    text: message.message,
    senderName: sender ? sender.nickname || sender.userId : '',
    mine: !!sender && sender.userId === myUserId,
    isAdmin: message.isAdminMessage(),
  };
}

// Keep the rendered list with this for every batch (added, updated, older/newer pages):
// it replaces matching rows and returns the list oldest first.
export function mergeMessages(current: BaseMessage[], incoming: BaseMessage[]): BaseMessage[] {
  const kept = current.filter((m) => !incoming.some((n) => sameMessage(m, n)));
  return [...kept, ...incoming].sort((a, b) => a.createdAt - b.createdAt);
}

// Call once when the screen mounts. onCache/onApi get the page oldest first; each replaces
// the whole list. Merge onAdded/onUpdated into the list with mergeMessages.
export function initializeMessageList(
  collection: ReturnType<typeof createMessageListCollection>,
  handlers: {
    onCache: (messages: BaseMessage[] | null) => void;
    onApi: (messages: BaseMessage[] | null) => void;
    onAdded: (messages: BaseMessage[]) => void;
    onUpdated: (messages: BaseMessage[]) => void;
    onDeleted: (messageIds: number[]) => void;
  },
) {
  collection
    .initialize(MessageCollectionInitPolicy.CACHE_AND_REPLACE_BY_API)
    .onCacheResult((_err: Error | null, messages: BaseMessage[] | null) => handlers.onCache(messages && mergeMessages([], messages)))
    .onApiResult((_err: Error | null, messages: BaseMessage[] | null) => handlers.onApi(messages && mergeMessages([], messages)));

  collection.setMessageCollectionHandler({
    onMessagesAdded: (_context: MessageEventContext, _channel: GroupChannel, messages: BaseMessage[]) => handlers.onAdded(messages),
    onMessagesUpdated: (_context: MessageEventContext, _channel: GroupChannel, messages: BaseMessage[]) => handlers.onUpdated(messages),
    // messageIds is deprecated since v4.3.1 in favor of the 4th `messages` arg — kept here
    // because it is still the simplest way to drop rows by id.
    onMessagesDeleted: (_context: MessageEventContext, _channel: GroupChannel, messageIds: number[], _messages: BaseMessage[]) =>
      handlers.onDeleted(messageIds),
  });

  return collection;
}

// Returns the older page; add it with mergeMessages(current, olderPage).
export async function loadOlderMessages(collection: ReturnType<typeof createMessageListCollection>) {
  if (!collection.hasPrevious) return [];
  return collection.loadPrevious();
}

// Send a text message. Merge every callback's message into the list with mergeMessages: the
// pending copy and the sent one share reqId, so the sent one replaces it. onFailed's message
// can be null (FailedMessageHandler<T> is (err, message: T | null)).
export function sendText(
  channel: GroupChannel,
  text: string,
  handlers: {
    onPending: (message: BaseMessage) => void;
    onSucceeded: (message: BaseMessage) => void;
    onFailed: (error: Error, message: BaseMessage | null) => void;
  },
) {
  return channel
    .sendUserMessage({ message: text })
    .onPending((message) => handlers.onPending(message))
    .onSucceeded((message) => handlers.onSucceeded(message))
    .onFailed((error, message) => handlers.onFailed(error, message));
}

export async function toggleReaction(channel: GroupChannel, message: BaseMessage, key: string, alreadyReacted: boolean) {
  return alreadyReacted ? channel.deleteReaction(message, key) : channel.addReaction(message, key);
}

export async function markChannelRead(channel: GroupChannel) {
  await channel.markAsRead();
}

// Debounce startTyping/endTyping in the caller — do not call on every keystroke.
export async function setTyping(channel: GroupChannel, isTyping: boolean) {
  return isTyping ? channel.startTyping() : channel.endTyping();
}
