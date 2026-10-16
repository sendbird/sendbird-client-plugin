// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannel.html (startTyping, endTyping, getTypingUsers, getUnreadMemberCount, getReadMembers, markAsRead)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelHandler.html (onTypingStatusUpdated, onUserMarkedRead)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelModule.html (addGroupChannelHandler, removeGroupChannelHandler)
// source: knowledge/curated/js/products/chat.md ("Typing indicator (group channels)", "Read receipts for a message")
// Verified against the @sendbird/chat 4.22.11 and 4.22.14 type declarations: GroupChannel startTyping(), endTyping(),
// getTypingUsers(): Member[], getUnreadMemberCount(message), getReadMembers(message, includeAllMembers?), markAsRead(), url;
// GroupChannelHandler onTypingStatusUpdated(channel) and onUserMarkedRead(channel, userIds). Not used on purpose:
// onUnreadMemberStatusUpdated, deprecated since v4.18.2. Type-checked by tools/templates/compile-check-js.sh against the
// pinned and latest packages. (GroupChannelMessages.tsx keeps its simpler setTyping / markChannelRead helpers.)

import { useEffect, useState } from 'react';
import type { GroupChannel, SendbirdGroupChat } from '@sendbird/chat/groupChannel';
import { GroupChannelHandler } from '@sendbird/chat/groupChannel';
import type { BaseMessage } from '@sendbird/chat/message';

/**
 * Typing users and a read-receipt counter for one open conversation. `readReceiptsVersion` goes up each time another
 * member reads messages; components that draw read marks use it so they re-render.
 */
export function useChannelActivity(sb: SendbirdGroupChat, channel: GroupChannel) {
  const [typingNames, setTypingNames] = useState<string[]>([]);
  const [readReceiptsVersion, setReadReceiptsVersion] = useState(0);

  useEffect(() => {
    const key = `channel-activity-${channel.url}`;
    sb.groupChannel.addGroupChannelHandler(
      key,
      new GroupChannelHandler({
        onTypingStatusUpdated: (updated: GroupChannel) => {
          if (updated.url === channel.url) setTypingNames(updated.getTypingUsers().map((member) => member.nickname));
        },
        onUserMarkedRead: (updated: GroupChannel, _userIds: string[]) => {
          if (updated.url === channel.url) setReadReceiptsVersion((version) => version + 1);
        },
      }),
    );
    channel.markAsRead().catch(() => {});
    return () => {
      sb.groupChannel.removeGroupChannelHandler(key);
      channel.endTyping().catch(() => {});
    };
  }, [sb, channel]);

  return { typingNames, readReceiptsVersion };
}

/** Call from the input's onChange: typing starts while there is text and ends when it is cleared or sent. */
export function onDraftChange(channel: GroupChannel, draft: string) {
  return draft.length > 0 ? channel.startTyping() : channel.endTyping();
}

/** How many members have not read `message` yet; 0 means everyone has read it. */
export function unreadMemberCount(channel: GroupChannel, message: BaseMessage) {
  return channel.getUnreadMemberCount(message);
}

/** Members (other than the current user) who have read `message`. */
export function readers(channel: GroupChannel, message: BaseMessage) {
  return channel.getReadMembers(message, false);
}
