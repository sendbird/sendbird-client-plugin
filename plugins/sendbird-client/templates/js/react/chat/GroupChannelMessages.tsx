// source: @sendbird/chat 4.22.13 shipped type declarations (lib/__definition.d.ts,
// verified 2026-09-29) — GroupChannel.createMessageCollection, MessageCollection
// (initialize/onCacheResult/onApiResult/setMessageCollectionHandler/loadPrevious/
// loadNext/hasPrevious/hasNext), BaseChannel.addReaction/deleteReaction,
// GroupChannel.startTyping/endTyping/getTypingUsers/markAsRead. Type-checked
// with `tsc --strict --skipLibCheck` against the real package.
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

// Call once when the screen mounts.
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
    .onCacheResult((_err: Error | null, messages: BaseMessage[] | null) => handlers.onCache(messages))
    .onApiResult((_err: Error | null, messages: BaseMessage[] | null) => handlers.onApi(messages));

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

export async function loadOlderMessages(collection: ReturnType<typeof createMessageListCollection>) {
  if (!collection.hasPrevious) return [];
  return collection.loadPrevious();
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
