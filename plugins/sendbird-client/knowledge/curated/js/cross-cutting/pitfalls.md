<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# js — pitfalls

> Common JS / React / React Native integration mistakes. Each API named is cited inline or in the linked product docs. Verified 2026-09-30.

## Setup

- `SendbirdChat.init(...)` once; reuse the `sb` instance (see chat.md).
- React UIKit: import `@sendbird/uikit-react/dist/index.css` or the UI is unstyled (see uikit.md).
- React Native UIKit/AI Agent: `platformServices` / `nativeModules` (mmkv) are required — follow the quickstart, don't guess factory calls.
- React Native 0.87+: `<StatusBar backgroundColor=...>` fails type-checking because 0.87 removed the prop; color the top view behind the status bar instead (see theme.md, Status bar).
- React Native 0.87+: `FlatList`'s `ListEmptyComponent` and the other list element props take an element, a component, or `undefined`, not `null`, so `cond ? <Text>…</Text> : null` fails type-checking (TS2322); write `: undefined` (see chat.md, React vs React Native). (source: @react-native/virtualized-lists@0.87.1 types_generated/Lists/VirtualizedListProps.d.ts:140, :145, :154)

## Auth

- Set the `SessionHandler` (`import { SessionHandler } from '@sendbird/chat'`) before `connect` (see auth.md).
- Tokens are secrets — read from env, never hard-code or commit.

## Lifecycle (React)

- Remove group-channel handlers in `useEffect` cleanup (see performance.md); add on mount, remove on unmount.
- Don't recreate the SDK instance or modules on every render.

## Connection lifecycle

- `disconnect()` logs out: it closes the connection and clears cached data. `disconnectWebSocket()` closes only the socket and keeps `currentUser` and cache; reconnect with `sb.connect()`. `setBackgroundState()` / `setForegroundState()` are the pair to use for app backgrounding. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4388-4403 ; https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication)
- Web: by default (`appStateToggleEnabled: true`) the SDK closes the WebSocket after the tab has been hidden for 30 seconds and recovers when the page is visible again. Pass `appStateToggleEnabled: false` to `SendbirdChat.init()` to manage the connection yourself. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation)
- `MessageCollection` does not document the order of the `onCacheResult` / `onApiResult` array. Rendering it as it arrives can show the newest message at the top when a cached channel is reopened. Send every batch, the initial ones included, through one merge that sorts by `createdAt` (see chat.md "List and receive messages"). (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:2579-2596 ; https://github.com/sendbird/sendbird-chat-sample-react/blob/main/src/samples/BasicGroupChannelSample.js)
- After a long offline period, `MessageCollection` may call `onHugeGapDetected`; `dispose()` the collection and create a new one instead of reusing it. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/using-message-collection/message-collection)
- Use a `ConnectionHandler` (`onReconnectStarted` / `onReconnectSucceeded` / `onReconnectFailed` / `onConnectionLost`) to observe reconnection instead of polling `connectionState`. Stay on 4.22.8 or later: it fixes a WebSocket that could stay stuck after a ping/pong timeout or a background/hidden-page close. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:1320-1335 ; @sendbird/chat CHANGELOG.md v4.22.8)

## Switching app ID

Keep a reference to the instance you connected and `await sb.disconnect()` on **that** instance before calling `SendbirdChat.init()` with another app ID. Don't look it up again through `SendbirdChat.instance` at cleanup time, because that getter returns whichever instance is currently active. Use 4.22.10 or later: earlier versions could return the instance still bound to the previous app when `init()` was called with a different `appId`. From 4.22.10, `init()` releases the previous app's instance itself.

```ts
import SendbirdChat from '@sendbird/chat';
import { GroupChannelModule, type SendbirdGroupChat } from '@sendbird/chat/groupChannel';

let sb = SendbirdChat.init({ appId: APP_ID_A, modules: [new GroupChannelModule()] }) as SendbirdGroupChat;
await sb.connect(USER_ID);

await sb.disconnect(); // the instance you actually connected
sb = SendbirdChat.init({ appId: APP_ID_B, modules: [new GroupChannelModule()] }) as SendbirdGroupChat;
await sb.connect(USER_ID);
```

React UIKit: `SendbirdProvider` reuses the cached singleton, so rendering providers for two app IDs on one page replaces it; pass `sdkInitParams={{ newInstance: true }}` to a provider that needs its own instance. (source: @sendbird/chat@4.22.13 lib/__definition.d.ts:4240-4246 ; @sendbird/chat CHANGELOG.md v4.22.10 ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:130-136)

## File messages: final state and resend

When a chat view uses `MessageCollection`, treat `onMessagesUpdated` as the source of truth for a sent message's outcome: it fires when a pending message's send status changes, and `message.sendingStatus` then reads `SendingStatus.SUCCEEDED` or `FAILED`. The collection also exposes `pendingMessages` and `failedMessages`. To retry, use `channel.resendMessage(failedMessage, file?)`; `resendFileMessage()` is deprecated since 4.9.8. Pass the original `File` / `Blob` / `FileInfo` as the second argument if you still hold it, and check `message.isResendable` first.

```ts
import { SendingStatus } from '@sendbird/chat/message';

collection.setMessageCollectionHandler({
  onMessagesUpdated: (_context, _channel, messages) => {
    for (const message of messages) {
      if (!message.isFileMessage()) continue;
      if (message.sendingStatus === SendingStatus.SUCCEEDED) { /* final success */ }
      else if (message.sendingStatus === SendingStatus.FAILED && message.isResendable) { /* offer retry */ }
    }
  },
});

channel.resendMessage(failedFileMessage, originalFile)
  .onSucceeded((sent) => { /* sent.messageId */ })
  .onFailed((err, msg) => { /* still failed */ });
```

(source: @sendbird/chat@4.22.13 lib/__definition.d.ts:487-496,957-962,1034,2214,4222-4226,4939-4945 ; https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/using-message-collection/message-collection)

## Joined-channel limit

A user can be a member of at most 2,000 group channels. Once a user reaches the limit, new invitations are automatically declined, so auto-accept (`sb.setChannelInvitationPreference(true)`) does not help. Users who collect many channels should leave inactive ones. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/channel/inviting-users-to-a-group-channel/accept-or-decline-an-invitation ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4564)

## Calls

- Web Calls: call `connectWebSocket()` after `authenticate`, or events won't arrive (see calls.md).

## Related

- Setup: knowledge/curated/js/setup.md
- Performance: knowledge/curated/js/cross-cutting/performance.md
