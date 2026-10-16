// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat_groupChannel.GroupChannelModule.html (getTotalUnreadMessageCount)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/ref/classes/_sendbird_chat.default.html (addUserEventHandler, removeUserEventHandler)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/event-handler/managing-user-event-handlers/add-or-remove-a-user-event-handler
// source: knowledge/curated/js/products/chat.md ("Unread counts")
// Verified against the @sendbird/chat 4.22.11 and 4.22.14 type declarations: GroupChannelModule
// getTotalUnreadMessageCount(params?): Promise<number>; SendbirdChat addUserEventHandler(key, UserEventHandler) /
// removeUserEventHandler(key); UserEventHandler onTotalUnreadMessageCountChanged(UnreadMessageCount) with groupChannelCount;
// GroupChannel unreadMessageCount, markAsRead(). Not used on purpose: onTotalUnreadMessageCountUpdated (deprecated) and the
// FeedChannelModule getTotalUnreadMessageCount (deprecated since 4.13.0). Type-checked by
// tools/templates/compile-check-js.sh against the pinned and latest packages.

import { useCallback, useEffect, useState } from 'react';
import { UserEventHandler } from '@sendbird/chat';
import type { GroupChannel, SendbirdGroupChat, UnreadMessageCount } from '@sendbird/chat/groupChannel';

/**
 * The total unread message count for a tab or header badge. Use it once the user is connected (pass null before).
 * `refresh` re-reads the total; call it after markChannelRead and when AppState changes back to 'active'.
 */
export function useTotalUnreadCount(sb: SendbirdGroupChat | null) {
  const [total, setTotal] = useState(0);

  const refresh = useCallback(async () => {
    if (!sb) return;
    setTotal(await sb.groupChannel.getTotalUnreadMessageCount());
  }, [sb]);

  useEffect(() => {
    if (!sb) return undefined;
    const key = 'unread-count-badge';
    sb.addUserEventHandler(
      key,
      new UserEventHandler({
        onTotalUnreadMessageCountChanged: (count: UnreadMessageCount) => setTotal(count.groupChannelCount),
      }),
    );
    refresh().catch(() => {});
    return () => sb.removeUserEventHandler(key);
  }, [sb, refresh]);

  return { total, refresh };
}

/** The badge for one row of the channel list. */
export function channelUnreadCount(channel: GroupChannel) {
  return channel.unreadMessageCount;
}

/** Resets one channel's count when the user opens it. */
export async function markChannelReadAndRefresh(channel: GroupChannel, refresh: () => Promise<void>) {
  await channel.markAsRead();
  await refresh();
}
