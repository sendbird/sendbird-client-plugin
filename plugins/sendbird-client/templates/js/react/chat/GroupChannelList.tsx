// source: @sendbird/chat 4.22.13 shipped type declarations (lib/__definition.d.ts,
// verified 2026-09-29) — GroupChannelModule.createGroupChannelCollection,
// BaseChannelCollection (setGroupChannelCollectionHandler/loadMore/hasMore),
// GroupChannelCollection.dispose. Type-checked with `tsc --strict --skipLibCheck`
// against the real package.
//
// A live-updating group channel list: first page + real-time add/update/delete.
// Pair with GroupChannelMessages.tsx for the conversation screen.

import type { GroupChannel, GroupChannelEventContext, SendbirdGroupChat } from '@sendbird/chat/groupChannel';
import { GroupChannelFilter, GroupChannelListOrder } from '@sendbird/chat/groupChannel';
import type { BaseChannel } from '@sendbird/chat';

// `sb` is the value returned by `SendbirdChat.init({ modules: [new GroupChannelModule()] })`.
export function createChannelListCollection(sb: SendbirdGroupChat) {
  return sb.groupChannel.createGroupChannelCollection({
    filter: new GroupChannelFilter(),
    order: GroupChannelListOrder.LATEST_LAST_MESSAGE,
  });
}

// Call once when the screen mounts. Returns the collection so the caller can
// `dispose()` it on unmount and call `loadMore()` again to paginate.
export function subscribeChannelList(
  collection: ReturnType<typeof createChannelListCollection>,
  handlers: {
    onAdded: (channels: GroupChannel[]) => void;
    onUpdated: (channels: GroupChannel[]) => void;
    onDeleted: (channelUrls: string[]) => void;
  },
) {
  // The SDK types onChannelsAdded/onChannelsUpdated as `BaseChannel[]` even though a
  // GroupChannelCollection only ever emits GroupChannel instances.
  collection.setGroupChannelCollectionHandler({
    onChannelsAdded: (_context: GroupChannelEventContext, channels: BaseChannel[]) => handlers.onAdded(channels as GroupChannel[]),
    onChannelsUpdated: (_context: GroupChannelEventContext, channels: BaseChannel[]) => handlers.onUpdated(channels as GroupChannel[]),
    onChannelsDeleted: (_context: GroupChannelEventContext, channelUrls: string[]) => handlers.onDeleted(channelUrls),
  });
  return collection.loadMore(); // first page; call again while collection.hasMore to paginate
}
