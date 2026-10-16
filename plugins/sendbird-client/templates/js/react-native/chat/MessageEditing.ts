// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html (updateUserMessage, deleteMessage, url)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelModule.html (addGroupChannelHandler, removeGroupChannelHandler)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html (currentUser)
// source: knowledge/curated/js/products/chat.md ("Update and delete a message")
// Verified against the @sendbird/chat 4.22.11 and 4.22.14 type declarations: BaseChannel updateUserMessage(messageId,
// UserMessageUpdateParams): Promise<UserMessage>, deleteMessage(BaseMessage): Promise<void>; SendbirdChat currentUser;
// GroupChannelModule addGroupChannelHandler(key, GroupChannelHandler) / removeGroupChannelHandler(key); GroupChannelHandler
// onMessageUpdated(channel, message) / onMessageDeleted(channel, messageId). Type-checked by
// tools/templates/compile-check-js.sh against the pinned and latest packages.
// A user can update or delete messages they sent; channel operators can update or delete any message.

import type { GroupChannel, SendbirdGroupChat } from '@sendbird/chat/groupChannel';
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';
import type { BaseChannel } from '@sendbird/chat';
import type { BaseMessage, UserMessage } from '@sendbird/chat/message';

/** True when the connected user sent `message`; show Edit and Delete only for those. */
export function isMine(sb: SendbirdGroupChat, message: UserMessage) {
  return !!sb.currentUser && message.sender.userId === sb.currentUser.userId;
}

/** Replaces the text of a user message; resolves with the updated message to put in the list. */
export function editMessage(channel: GroupChannel, message: UserMessage, newText: string) {
  return channel.updateUserMessage(message.messageId, { message: newText });
}

/** Deletes a message for everyone in the channel; remove the row when it resolves. */
export function deleteMessage(channel: GroupChannel, message: BaseMessage) {
  return channel.deleteMessage(message);
}

/**
 * Tells one open conversation that another member edited or deleted a message. Call in a useEffect and return the
 * result as its cleanup. A screen that shows messages through a MessageCollection (createMessageCollection) already
 * gets these changes from its collection handler and does not need this.
 */
export function watchMessageChanges(
  sb: SendbirdGroupChat,
  channelUrl: string,
  handlers: { onUpdated: (message: BaseMessage) => void; onDeleted: (messageId: number) => void },
) {
  const key = `message-changes-${channelUrl}`;
  sb.groupChannel.addGroupChannelHandler(
    key,
    new GroupChannelHandler({
      onMessageUpdated: (channel: BaseChannel, message: BaseMessage) => {
        if (channel.url === channelUrl) handlers.onUpdated(message);
      },
      onMessageDeleted: (channel: BaseChannel, messageId: number) => {
        if (channel.url === channelUrl) handlers.onDeleted(messageId);
      },
    }),
  );
  return () => sb.groupChannel.removeGroupChannelHandler(key);
}
