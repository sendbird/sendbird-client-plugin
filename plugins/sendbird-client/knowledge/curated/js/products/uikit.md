<!-- last-verified-against: @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.10 -->
<!-- status: populated -->
# js uikit

> Verified against the public mirrors `sendbird/sendbird-uikit-react` and `sendbird/sendbird-uikit-react-native`. React and React Native templates type-checked against pinned and latest packages, including 3.19.1 and 3.12.9, on 2026-09-22. The `SendbirdUIKitContainer` props cited below (`appId`, `platformServices`) were re-verified against `@sendbird/uikit-react-native` 3.12.10 shipped types on 2026-10-05 (patch bump, no change to the cited surface). The GroupChannelList/GroupChannel prop sections below are verified against the `sendbird-uikit-react` repo's actual TSX source at `main` (verified 2026-09-29) — the package's own shipped `types/index.d.ts` is a stale/legacy export surface and does not match the runtime component tree, so props are cited from source, not from the package's `.d.ts`. Cite each symbol; do not add API from memory.
> Sources: https://github.com/sendbird/sendbird-uikit-react , https://github.com/sendbird/sendbird-uikit-react-native

## React (`@sendbird/uikit-react`)
Install: `npm i @sendbird/uikit-react` (peers: `@sendbird/chat`, react 18+).

Drop-in full app:
```tsx
import SendbirdApp from '@sendbird/uikit-react/App';
import '@sendbird/uikit-react/dist/index.css';

<SendbirdApp appId={APP_ID} userId={USER_ID} theme="light" nickname={nickname} profileUrl={profileUrl} allowProfileEdit={false} />
```
`AppProps` (`appId`, `userId`, `theme`, `nickname`, `profileUrl`, `allowProfileEdit`, …) forwards straight into `SendbirdProviderProps` — same names, same types. (source: `sendbird-uikit-react` src/modules/App/index.tsx:17-35 `AppProps`)

### Compose your own UI: channel list + conversation
For a custom layout (e.g. a two-pane screen instead of the drop-in `App`), use `GroupChannelList` and `GroupChannel` directly instead of `App`:
```tsx
import { useState } from 'react';
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannelList } from '@sendbird/uikit-react/GroupChannelList';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import '@sendbird/uikit-react/dist/index.css';

function ChatScreen() {
  const [channelUrl, setChannelUrl] = useState<string | null>(null);
  return (
    <SendbirdProvider appId={APP_ID} userId={USER_ID}>
      <GroupChannelList
        onChannelSelect={(channel) => setChannelUrl(channel?.url ?? null)}
        onChannelCreated={(channel) => setChannelUrl(channel.url)}
        disableAutoSelect={false}
      />
      {channelUrl && (
        <GroupChannel
          channelUrl={channelUrl}
          onBackClick={() => setChannelUrl(null)}
          isReactionEnabled
          replyType="THREAD"
        />
      )}
    </SendbirdProvider>
  );
}
```
`GroupChannelListProps` (required `onChannelSelect(channel: GroupChannel | null)`, `onChannelCreated(channel)`; optional `disableAutoSelect`, `allowProfileEdit`, `channelListQueryParams`) and `GroupChannelProviderProps` (required `channelUrl`; optional `isReactionEnabled`, `isMessageGroupingEnabled`, `replyType`, `onBackClick()`, `onChatHeaderActionClick(event)`, `onBeforeSendUserMessage`, `onBeforeSendFileMessage`, `startingPoint`) are the real prop surfaces — the shipped root `.d.ts` describes an older v2-style API (`ChannelList`, `withSendBird`) that the current runtime no longer exports at the package root; do not use those names. (source: `sendbird-uikit-react` src/modules/GroupChannelList/context/GroupChannelListProvider.tsx:29-30,37-38,44,55-57 `GroupChannelListProviderProps`; src/modules/GroupChannel/context/types.ts:77-120 `GroupChannelProviderProps`)

A channel list screen opens the channel the user picks: store the selected URL from `onChannelSelect` (and `onChannelCreated`) and render `GroupChannel` for it, as above. Never pass a no-op such as `onChannelSelect={() => {}}`; the list then shows channels the user cannot open, and messages sent to them never appear. This holds even when the request names only a channel list.

For a phone layout that shows one pane at a time: `GroupChannel` draws its header back button (the one that calls `onBackClick`) only in UIKit's mobile mode, which turns on when `SendbirdProvider`'s `breakpoint` matches the screen (for example `breakpoint="768px"`; `true` turns mobile mode on at every width). The default is `false`, so without it the button never appears and the user cannot get back to the list. Also pass `disableAutoSelect` to `GroupChannelList` on a phone: otherwise the list selects the first channel as soon as nothing is selected, which opens a conversation right after sign-in and again after every back tap. `templates/starters-bp/react` does both. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/MediaQueryContext.tsx#L4-L60 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/components/GroupChannelHeader/GroupChannelHeaderView.tsx#L38-L56 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannelList/context/GroupChannelListProvider.tsx#L141-L146 ; @sendbird/uikit-react 3.19.1 types/lib/Sendbird/types.d.ts:156 `breakpoint?: string | boolean`)

Read SDK connection/store state for advanced cases with `useSendbirdStateContext()` (exported for backward-compat; prefer driving UI through props above where possible). (source: `sendbird-uikit-react` src/lib/Sendbird/context/hooks/useSendbirdStateContext.tsx)

The customization sections below cite the subpath type files that `@sendbird/uikit-react` 3.19.1 ships (each subpath's `exports` entry points at `types/modules/...` or `types/ui/...`, which match the source) and the public source at tag `v3.19.1`. Their examples type-check against the pinned and latest packages. Only the root `types/index.d.ts` is the stale file mentioned above.

### Customize how messages render
`GroupChannel` takes three levels of message customization. Pick the narrowest one that does the job, because each wider level gives up more of the default UI.

- `renderMessageContent(props)` replaces the content block of each message (avatar, bubble, menus, reactions). Inside it, `MessageContent` accepts `renderMessageBody`, `renderMessageHeader`, `renderSenderProfile`, `renderMessageMenu`, `renderEmojiMenu`, and `renderEmojiReactions`, so you can swap only the body and keep everything else.
- `renderMessage(props)` replaces the whole row. Return `<Message {...props}>…</Message>` with your own children: `Message` still draws the date separator and the "New Messages" line, and your children replace everything below them. Return `<Message {...props} />` to keep the default for the messages you don't customize.
- `renderMessage` on `Message` itself is deprecated in favor of `children`; the `renderMessage` prop on `GroupChannel` is not.

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { Message } from '@sendbird/uikit-react/GroupChannel/components/Message';

<GroupChannel
  channelUrl={CHANNEL_URL}
  renderMessage={(props) => {
    const { message } = props;
    if (message.isUserMessage() && message.customType === 'promotion') {
      return (
        <Message {...props}>
          <div className="promo-card">{message.message}</div>
        </Message>
      );
    }
    return <Message {...props} />;
  }}
/>
```

File messages: to change how one file type looks while keeping the avatar, menu, reactions, and send status, replace only the body. `bodyProps.message` is a `UserMessage | FileMessage | MultipleFilesMessage | AdminMessage`, so narrow it with `isFileMessage()` first.

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import MessageContent, { MessageBody } from '@sendbird/uikit-react/ui/MessageContent';

<GroupChannel
  channelUrl={CHANNEL_URL}
  renderMessageContent={(props) => (
    <MessageContent
      {...props}
      renderMessageBody={(bodyProps) => {
        const { message } = bodyProps;
        if (message.isFileMessage() && message.type === 'application/pdf') {
          return (
            <a className="pdf-card" href={message.url} target="_blank" rel="noreferrer">
              {message.name}
            </a>
          );
        }
        return <MessageBody {...bodyProps} />;
      }}
    />
  )}
  onBeforeDownloadFileMessage={async ({ message }) => window.confirm(`Download ${message.isFileMessage() ? message.name : 'these files'}?`)}
/>
```

`onBeforeDownloadFileMessage` (3.13.3+) runs before the default file bubble opens a file; resolve `false` to cancel. It only affects the default body, not a body you render yourself.

Messages from users you blocked: the docs say that in a 1-to-N group channel the user may still receive messages from a blocked user, depending on the chat view. To hide or replace them, check `sender.isBlockedByMe` (a `Sender` field) in `renderMessage`:

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { Message } from '@sendbird/uikit-react/GroupChannel/components/Message';

<GroupChannel
  channelUrl={CHANNEL_URL}
  renderMessage={(props) => {
    const { message } = props;
    if ((message.isUserMessage() || message.isFileMessage()) && message.sender.isBlockedByMe) {
      return (
        <Message {...props}>
          <div className="blocked-message">Message from a blocked user</div>
        </Message>
      );
    }
    return <Message {...props} />;
  }}
/>
```
(source: https://sendbird.com/docs/chat/sdk/v4/javascript/user/moderating-a-user/block-and-unblock-other-members ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4927-4936 — `Sender.isBlockedByMe`)

(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/components/Message/MessageView.tsx lines 323-331 and 479-498 — children first, then `renderMessage`; the separators are drawn outside both ; src/modules/GroupChannel/components/MessageList/index.tsx:67 — the default `renderMessage` is `<Message {...props} />` ; src/ui/FileMessageItemBody/index.tsx:43-55 ; @sendbird/uikit-react@3.19.1 types/modules/GroupChannel/components/GroupChannelUI/GroupChannelUIView.d.ts:37,41 `renderMessage`, `renderMessageContent` ; types/modules/GroupChannel/components/Message/MessageView.d.ts:11-51 `MessageProps` (`children` at 21, deprecated `renderMessage` at 46-50) ; types/types.d.ts:50 `RenderMessageParamsType` ; types/ui/MessageContent/index.d.ts:16,19-60 `MessageBody`, `MessageContentProps`, `MessageComponentRenderers` ; types/ui/MessageContent/MessageBody/index.d.ts:9-22 ; types/utils/index.d.ts:48 `CoreMessageType` ; types/modules/GroupChannel/context/types.d.ts:17-20,72 `onBeforeDownloadFileMessage` ; CHANGELOG.md v3.13.3)

### Message menu items
On the web, each message has a menu button. To change its items, render `MessageContent` from `renderMessageContent` and give it `renderMessageMenu`, which returns `MessageMenu` with `renderMenuItems`. `renderMenuItems` receives the built-in items in `items` (`CopyMenuItem`, `ReplyMenuItem`, `ThreadMenuItem`, `OpenInChannelMenuItem`, `EditMenuItem`, `ResendMenuItem`, `DeleteMenuItem`, `MarkAsUnreadMenuItem`); the items you return, in that order, are the menu. `MenuItem` makes an item of your own. On mobile layouts the docs use `MobileMenu` from `@sendbird/uikit-react/ui/MobileMenu` the same way.

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import MessageContent from '@sendbird/uikit-react/ui/MessageContent';
import { MessageMenu, MenuItem } from '@sendbird/uikit-react/ui/MessageMenu';

function ChannelWithShortMenu({ channelUrl, onReport }: { channelUrl: string; onReport: (messageId: number) => void }) {
  return (
    <GroupChannel
      channelUrl={channelUrl}
      renderMessageContent={(contentProps) => (
        <MessageContent
          {...contentProps}
          renderMessageMenu={(menuProps) => (
            <MessageMenu
              {...menuProps}
              renderMenuItems={({ items }) => (
                <>
                  <items.CopyMenuItem />
                  <items.ReplyMenuItem />
                  <items.DeleteMenuItem />
                  <MenuItem onClick={() => onReport(menuProps.message.messageId)}>Report</MenuItem>
                </>
              )}
            />
          )}
        />
      )}
    />
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react/tutorial/customize-message-menu) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/ui/MessageMenu/MessageMenu.tsx ; @sendbird/uikit-react 3.19.1 types/ui/MessageMenu/MessageMenu.d.ts:7-27 — `RenderMenuItemsParams`, `renderMenuItems` ; types/ui/MessageMenu/index.d.ts:2-4 ; types/ui/MessageContent/index.d.ts:55)

### Message input: icons, attach button, disabling, file types
- `renderSendMessageIcon`, `renderVoiceMessageIcon`, and `renderFileUploadIcon` are `GroupChannel` props. The send and voice renderers replace only the icon; UIKit keeps its own button and click handler around it.
- `renderFileUploadIcon` is different: whatever it returns replaces the whole attach button, including the hidden `<input type="file">` and its click handler. A custom attach control must open its own picker and send the file itself, for example with `sendFileMessage` from `useGroupChannel().actions`.
- To hide the attach button instead, set `uikitOptions.groupChannel.input.enableDocument: false` on `SendbirdProvider`; the default button renders only while that option is on. `uikitOptions.groupChannel.enableVoiceMessage` controls the voice button the same way.
- To disable the input or limit file types, render the default composer yourself with `renderMessageInput` and `MessageInputWrapper`, whose props are `value`, `disabled`, `acceptableMimeTypes`, and the three icon renderers. `disabled` is added to UIKit's own conditions (frozen channel, muted user, offline without local cache, …), and the placeholder then shows the `MESSAGE_INPUT__PLACE_HOLDER__DISABLED` string.

```tsx
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { MessageInputWrapper } from '@sendbird/uikit-react/GroupChannel/components/MessageInputWrapper';

function SupportChat({ canSend }: { canSend: boolean }) {
  return (
    <SendbirdProvider appId={APP_ID} userId={USER_ID} uikitOptions={{ groupChannel: { enableVoiceMessage: false } }}>
      <GroupChannel
        channelUrl={CHANNEL_URL}
        renderMessageInput={() => (
          <MessageInputWrapper disabled={!canSend} acceptableMimeTypes={['image/png', 'image/jpeg', 'application/pdf']} />
        )}
      />
    </SendbirdProvider>
  );
}
```

A custom attach button that sends through the channel's own action, so the message shows up in the list like any other send:

```tsx
import { useRef } from 'react';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { useGroupChannel } from '@sendbird/uikit-react/GroupChannel/context';

function AttachButton() {
  const { actions } = useGroupChannel();
  const inputRef = useRef<HTMLInputElement>(null);
  return (
    <>
      <button type="button" onClick={() => inputRef.current?.click()}>Attach</button>
      <input
        ref={inputRef}
        type="file"
        hidden
        onChange={(event) => {
          const picked = event.target.files?.[0];
          if (picked) actions.sendFileMessage({ file: picked });
          event.target.value = '';
        }}
      />
    </>
  );
}

<GroupChannel channelUrl={CHANNEL_URL} renderFileUploadIcon={() => <AttachButton />} />
```

`MessageInputWrapperProps` in 3.19.1 has only the props listed above. Some older examples on the docs site pass `onSendUserMessage` / `onSendFileMessage` to it; those are not in the shipped type. To change what gets sent, use `onBeforeSendUserMessage` / `onBeforeSendFileMessage` on `GroupChannel` instead.

(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/ui/MessageInput/index.tsx lines 668-738 — the send and voice renderers sit inside UIKit's button; the file renderer replaces the button and its file input ; src/ui/MessageInput/messageInputUtils.ts:32-42 ; src/modules/GroupChannel/components/MessageInputWrapper/MessageInputWrapperView.tsx:102,114-121,417 ; @sendbird/uikit-react@3.19.1 types/modules/GroupChannel/components/GroupChannelUI/GroupChannelUIView.d.ts:33,57,61,65 ; types/modules/GroupChannel/components/MessageInputWrapper/index.d.ts:3-11 ; types/modules/GroupChannel/context/hooks/useGroupChannel.d.ts:14,25-28 ; types/modules/GroupChannel/context/index.d.ts:3 ; types/modules/GroupChannel/context/types.d.ts:67-68 ; types/lib/Sendbird/types.d.ts:122-128,159 `UIKitOptions` ; @sendbird/uikit-tools@0.2.0 dist/types/uikitConfiguration/types.d.ts:2-12,25 `input.enableDocument`, `enableVoiceMessage` ; https://sendbird.com/docs/chat/uikit/v3/react/modules/group-channel)

### Channel list: custom item, filter and search, loading state
- `renderChannelPreview(props)` replaces each row. It receives `channel`, `isSelected`, `isTyping`, `onLeaveChannel`, `onClick`, `tabIndex`, and `renderChannelAction`. UIKit wraps your element in a `<div onClick={onClick}>`, so a click already selects the channel; don't call `onClick` again inside.
- `channelListQueryParams` is merged into the `GroupChannelCollection` params and a `GroupChannelFilter`, so it accepts the Chat SDK filter fields (`channelNameContainsFilter`, `nicknameContainsFilter`, `customTypesFilter`, `includeEmpty`, …) plus `limit` and `order`. Since 3.14.14 the list recreates its collection when the values change, so a search box can drive it directly.
- `renderPlaceHolderLoading` shows until the first page loads; `renderPlaceHolderEmptyList` and `renderPlaceHolderError` cover the other two states. `renderHeader` replaces the list header.

```tsx
import { useState } from 'react';
import { GroupChannelList } from '@sendbird/uikit-react/GroupChannelList';

function ChannelSidebar({ onSelect }: { onSelect: (url: string | null) => void }) {
  const [search, setSearch] = useState('');
  return (
    <div>
      <input value={search} placeholder="Search channels" onChange={(e) => setSearch(e.target.value)} />
      <GroupChannelList
        onChannelSelect={(channel) => onSelect(channel?.url ?? null)}
        onChannelCreated={(channel) => onSelect(channel.url)}
        channelListQueryParams={{ includeEmpty: false, channelNameContainsFilter: search || undefined }}
        renderChannelPreview={({ channel, isSelected }) => (
          <div className={isSelected ? 'row row--selected' : 'row'}>
            <strong>{channel.name}</strong>
            <span>{channel.unreadMessageCount}</span>
          </div>
        )}
        renderPlaceHolderLoading={() => <div className="skeleton">Loading channels…</div>}
        renderPlaceHolderEmptyList={() => <div>No channels match.</div>}
      />
    </div>
  );
}
```

`channelNameContainsFilter` matches the channel name; `nicknameContainsFilter` matches member nicknames. To keep the default row and only add to it, render `GroupChannelListItem` (named export of `@sendbird/uikit-react/GroupChannelList/components/GroupChannelListItem`) with the props you received.

(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannelList/components/GroupChannelListItem/utils.ts ; src/modules/GroupChannelList/components/GroupChannelListUI/index.tsx:45-77 — the wrapper `div` with `onClick` ; src/modules/GroupChannelList/components/GroupChannelListUI/GroupChannelListUIView.tsx:60-79 ; src/modules/GroupChannelList/context/GroupChannelListProvider.tsx:148-158,288-293 ; CHANGELOG.md v3.14.14 ; @sendbird/uikit-react@3.19.1 types/modules/GroupChannelList/components/GroupChannelListUI/index.d.ts:6-12 ; types/modules/GroupChannelList/components/GroupChannelListItem/GroupChannelListItemView.d.ts:5-13 ; types/modules/GroupChannelList/components/GroupChannelListItem/index.d.ts:3-5 ; types/modules/GroupChannelList/context/GroupChannelListProvider.d.ts:15,25 `ChannelListQueryParamsType` ; @sendbird/chat@4.22.13 lib/__definition.d.ts:5384 `limit`, 5794 `nicknameContainsFilter`, 5812 `channelNameContainsFilter` ; https://sendbird.com/docs/chat/uikit/v3/react/modules/channel-list)

### Channel header
`renderChannelHeader` receives the default header's props. Return `GroupChannelHeader` with `renderLeft`, `renderMiddle`, or `renderRight` to replace one slot and keep the rest (title, back and info buttons). `GroupChannelListHeader` takes the same three slot props for the list header; its `renderTitle` is deprecated in favor of `renderMiddle`.

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { GroupChannelHeader } from '@sendbird/uikit-react/GroupChannel/components/GroupChannelHeader';

<GroupChannel
  channelUrl={CHANNEL_URL}
  renderChannelHeader={(props) => (
    <GroupChannelHeader
      {...props}
      renderRight={() => (
        <button type="button" onClick={() => window.open('/help', '_blank')}>Help</button>
      )}
    />
  )}
/>
```

Use `onChatHeaderActionClick` on `GroupChannel` if you only need to react to the default info button. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/components/GroupChannelHeader/GroupChannelHeaderView.tsx ; @sendbird/uikit-react@3.19.1 types/modules/GroupChannel/components/GroupChannelUI/GroupChannelUIView.d.ts:25 ; types/modules/GroupChannel/components/GroupChannelHeader/index.d.ts:3-6 ; types/ui/Header/index.d.ts:6-10 `HeaderCustomProps` ; types/modules/GroupChannelList/components/GroupChannelListHeader/index.d.ts:4-11 ; types/modules/GroupChannel/context/types.d.ts:74)

### Start a 1:1 chat from a button (no channel list)
Inside `SendbirdProvider`, get the create function with `sendbirdSelectors.getCreateGroupChannel(useSendbirdStateContext())`, create the channel with `isDistinct: true` (the existing 1:1 channel comes back when one has the same members), and show only `GroupChannel` for its URL. Sendbird's public router sample does the navigation part with react-router: the route `channels/:channelUrl` renders `GroupChannel channelUrl={channelUrl}`, and `onBackClick` navigates back.

```tsx
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import useSendbirdStateContext from '@sendbird/uikit-react/useSendbirdStateContext';
import sendbirdSelectors from '@sendbird/uikit-react/sendbirdSelectors';

// Render inside <SendbirdProvider>. onOpen navigates to your conversation route or sets state.
export function ChatWithSellerButton({ sellerUserId, onOpen }: { sellerUserId: string; onOpen: (channelUrl: string) => void }) {
  const createChannel = sendbirdSelectors.getCreateGroupChannel(useSendbirdStateContext());
  return (
    <button
      onClick={async () => {
        const created = await createChannel({ invitedUserIds: [sellerUserId], isDistinct: true });
        onOpen(created.url);
      }}
    >
      Chat with seller
    </button>
  );
}

// The conversation alone, without a channel list.
export function SellerChatPage({ channelUrl, onBack }: { channelUrl: string; onBack: () => void }) {
  return (
    <div style={{ height: '100vh' }}>
      <GroupChannel channelUrl={channelUrl} onBackClick={onBack} />
    </div>
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/samples/router/src/MobileLayout/Router.tsx#L9-L27 — `channels/:channelUrl` route) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/samples/router/src/MobileLayout/Channel.tsx#L6-L31 — `GroupChannel` for the route's channel URL) (source: @sendbird/uikit-react 3.19.1 types/lib/selectors.d.ts:76, 226-248 — `getCreateGroupChannel` and the default export ; types/lib/Sendbird/context/hooks/useSendbirdStateContext.d.ts:2-3 ; package.json `exports` `./sendbirdSelectors`, `./useSendbirdStateContext`) (source: knowledge/curated/js/products/chat.md — Create and list group channels)

Opening a channel from a browser notification tap is not covered here: these docs have no verified web push guide for `@sendbird/chat` (see knowledge/curated/js/cross-cutting/push.md).

### Threads
Set `replyType="THREAD"` on `GroupChannel` (or `uikitOptions.groupChannel.replyType: 'thread'` on the provider) to show "Reply in thread" in the message menu. The thread screen is a separate module, `Thread`, that you render yourself: `onReplyInThreadClick({ message })` on `GroupChannel` gives you the parent message, and `Thread` takes `channelUrl` and `message`. `onMoveToParentMessage` on `Thread` receives the parent message and its channel. `threadReplySelectType` decides whether tapping a reply in the channel opens the thread or scrolls to the parent message. Threads are one level deep, in group and supergroup channels only.

```tsx
import { useState } from 'react';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import Thread from '@sendbird/uikit-react/Thread';
import type { FileMessage, MultipleFilesMessage, UserMessage } from '@sendbird/chat/message';

type ParentMessage = UserMessage | FileMessage | MultipleFilesMessage; // UIKit's SendableMessageType

function ChannelWithThread({ channelUrl }: { channelUrl: string }) {
  const [parent, setParent] = useState<ParentMessage | null>(null);
  return (
    <>
      <GroupChannel
        channelUrl={channelUrl}
        replyType="THREAD"
        onReplyInThreadClick={({ message }) => setParent(message)}
      />
      {parent && (
        <Thread channelUrl={channelUrl} message={parent} onHeaderActionClick={() => setParent(null)} />
      )}
    </>
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react/features/message-threading/threads) (source: https://sendbird.com/docs/chat/uikit/v3/react/modules/thread) (source: @sendbird/uikit-react 3.19.1 types/modules/GroupChannel/context/types.d.ts:57-58, 75-77 — `replyType`, `threadReplySelectType`, `onReplyInThreadClick` ; types/modules/Thread/context/ThreadProvider.d.ts:10-18 — `channelUrl`, `message`, `onHeaderActionClick`, `onMoveToParentMessage` ; types/modules/Thread/index.d.ts ; types/utils/index.d.ts:49 — `SendableMessageType`)

**Message menu inside the thread.** Customizing the menu on `GroupChannel` (see "Message menu items" above) does not reach the thread screen, which draws its messages in two places with their own menus: the replies (`ThreadListItem`, drawn through `Thread`'s `renderMessage`) and the parent message at the top (`ParentMessageInfo`, drawn through `renderParentMessageInfo`). Both take `renderMessageMenu`, so give the same renderer to each. Keep the default class name on `ParentMessageInfo`, which is what the default renderer passes.

```tsx
import Thread from '@sendbird/uikit-react/Thread';
import ThreadListItem from '@sendbird/uikit-react/Thread/components/ThreadListItem';
import ParentMessageInfo from '@sendbird/uikit-react/Thread/components/ParentMessageInfo';
import { MessageMenu, type MessageMenuProps } from '@sendbird/uikit-react/ui/MessageMenu';
import type { FileMessage, MultipleFilesMessage, UserMessage } from '@sendbird/chat/message';

const copyAndDeleteOnly = (menuProps: MessageMenuProps) => (
  <MessageMenu
    {...menuProps}
    renderMenuItems={({ items }) => (
      <>
        <items.CopyMenuItem />
        <items.DeleteMenuItem />
      </>
    )}
  />
);

function ThreadWithShortMenu({ channelUrl, parent }: { channelUrl: string; parent: UserMessage | FileMessage | MultipleFilesMessage }) {
  return (
    <Thread
      channelUrl={channelUrl}
      message={parent}
      renderMessage={(props) => <ThreadListItem {...props} renderMessageMenu={copyAndDeleteOnly} />}
      renderParentMessageInfo={() => (
        <ParentMessageInfo className="sendbird-thread-ui__parent-message-info" renderMessageMenu={copyAndDeleteOnly} />
      )}
    />
  );
}
```
Type-checked against `@sendbird/uikit-react` 3.19.1 with `tsc --noEmit --strict`. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/Thread/components/ThreadUI/index.tsx#L43 — default `renderParentMessageInfo` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/Thread/components/ThreadList/index.tsx#L26 — default `renderMessage` is `ThreadListItem` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/Thread/components/ThreadList/ThreadListItem.tsx#L27 — `ThreadListItemProps` extends `MessageComponentRenderers` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/Thread/components/ThreadList/ThreadListItemContent.tsx#L97 — the reply falls back to its own `MessageMenu` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/Thread/components/ParentMessageInfo/index.tsx#L40-L46 — `renderMessageMenu` ; https://sendbird.com/docs/chat/uikit/v3/react/modules/thread)

### Channel settings menu
`ChannelSettings` draws its menu with `renderModerationPanel({ menuItems })`. `menuItems` has an `operator` and a `nonOperator` object; each key is one row (the operator rows are `operators`, `allUsers`, `mutedUsers`, `bannedUsers`, and `freezeChannel`; the non-operator row is `allUsers`), and the rows appear in key order. Return `MenuListByRole` with a changed copy to remove, reorder, or add rows; a row with `hideMenu: true` is skipped. `renderLeaveChannel` replaces the leave button, and `renderHeader` the header.

```tsx
import ChannelSettings from '@sendbird/uikit-react/ChannelSettings';
import { MenuListByRole } from '@sendbird/uikit-react/ChannelSettings/components/ChannelSettingMenuList';

function SettingsWithoutFreeze({ channelUrl }: { channelUrl: string }) {
  return (
    <ChannelSettings
      channelUrl={channelUrl}
      renderModerationPanel={({ menuItems }) => {
        const { freezeChannel, ...operatorRows } = menuItems.operator;
        return <MenuListByRole menuItems={{ ...menuItems, operator: operatorRows }} />;
      }}
    />
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react/tutorial/customize-channel-settings) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/ChannelSettings/components/ChannelSettingsUI/hooks/useMenuItems.tsx#L68-L120 — row keys ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/ChannelSettings/components/ChannelSettingsUI/MenuListByRole.tsx#L28 — `hideMenu` ; @sendbird/uikit-react 3.19.1 types/modules/ChannelSettings/components/ChannelSettingsUI/index.d.ts:6-14 ; types/modules/ChannelSettings/components/ChannelSettingsUI/MenuListByRole.d.ts)

**Member menu (the "..." on each member).** The member lists under the settings menu draw each row with `UserListItem`, and its "..." menu offers `OperatorToggleMenuItem`, `MuteToggleMenuItem`, and `BanToggleMenuItem`. Pass `renderUserListItem` to `ChannelSettings`, return `UserListItem` with `renderListItemMenu`, and return `UserListItemMenu` whose `renderMenuItems` lists the items you keep plus your own:

```tsx
import ChannelSettings from '@sendbird/uikit-react/ChannelSettings';
import UserListItem from '@sendbird/uikit-react/ui/UserListItem';
import { UserListItemMenu } from '@sendbird/uikit-react/ui/UserListItemMenu';

function SettingsMemberMenu({ channelUrl, onReport }: { channelUrl: string; onReport: (userId: string) => void }) {
  return (
    <ChannelSettings
      channelUrl={channelUrl}
      renderUserListItem={(itemProps) => (
        <UserListItem
          {...itemProps}
          key={itemProps.user.userId}
          renderListItemMenu={(menuProps) => (
            <UserListItemMenu
              {...menuProps}
              renderMenuItems={({ items }) => (
                <>
                  <items.OperatorToggleMenuItem />
                  <items.MuteToggleMenuItem />
                  <div onClick={() => onReport(itemProps.user.userId)}>Report</div>
                </>
              )}
            />
          )}
        />
      )}
    />
  );
}
```
Type-checked against `@sendbird/uikit-react` 3.19.1 with `tsc --noEmit --strict`. (source: https://sendbird.com/docs/chat/uikit/v3/react/tutorial/customize-channel-settings — "Member list" ; @sendbird/uikit-react 3.19.1 types/modules/ChannelSettings/context/types.d.ts:27 — `renderUserListItem` ; types/ui/UserListItem/index.d.ts:27 — `renderListItemMenu` ; types/ui/UserListItemMenu/UserListItemMenu.d.ts:4-17 — `RenderUserListItemMenuItemsParams`, `renderMenuItems`)

### Session tokens: `accessToken` and `configureSession`
When your Sendbird application requires a token to connect, UIKit for React takes it from two `SendbirdProvider` props.

1. Your server issues the access or session token for the user, and the app fetches it after its own sign-in. Never put the Platform API token or a fixed user token in the browser bundle.
2. Pass the token as `accessToken`. The provider calls the Chat SDK's `connect(userId, accessToken)` with it.
3. Pass `configureSession` for renewal. It is a function that receives the SDK instance and returns a Chat SDK `SessionHandler`; the provider sets that handler with `setSessionHandler` right before it connects. In `onSessionTokenRequired`, fetch a new token from your server and call `resolve(token)`, call `resolve(null)` to give up, or `reject(error)` on failure. In `onSessionClosed`, send the user back to your sign-in screen. See knowledge/curated/js/products/auth.md for when the SDK asks for a new token.
4. The provider connects again only when `appId` or `userId` changes. A new `accessToken` value on its own does not reconnect, so renew tokens through `configureSession`, not by re-rendering with a new prop.
5. The drop-in `App` takes `accessToken` but has no `configureSession` prop (3.19.1 and 3.20.0). If a token can expire while the page is open, use `SendbirdProvider` with `GroupChannelList` and `GroupChannel` instead (see "Compose your own UI" above).

```tsx
import { SessionHandler } from '@sendbird/chat';
import { SendbirdProvider, type SendbirdProviderProps } from '@sendbird/uikit-react/SendbirdProvider';
import { useState } from 'react';
import { GroupChannelList } from '@sendbird/uikit-react/GroupChannelList';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import '@sendbird/uikit-react/dist/index.css';

// Your app's call to your own server, which issues the token with the Platform API.
declare function fetchSessionToken(userId: string): Promise<string>;

export function SignedInChat({ userId, accessToken }: { userId: string; accessToken: string }) {
  const [channelUrl, setChannelUrl] = useState<string | null>(null);
  const configureSession: SendbirdProviderProps['configureSession'] = () => {
    const handler = new SessionHandler();
    handler.onSessionTokenRequired = (resolve, reject) => {
      fetchSessionToken(userId).then(resolve, reject);
    };
    handler.onSessionClosed = () => {
      // route to your sign-in screen
    };
    return handler;
  };
  return (
    <SendbirdProvider appId={APP_ID} userId={userId} accessToken={accessToken} configureSession={configureSession}>
      <GroupChannelList
        onChannelSelect={(channel) => setChannelUrl(channel?.url ?? null)}
        onChannelCreated={(channel) => setChannelUrl(channel.url)}
      />
      {channelUrl && <GroupChannel channelUrl={channelUrl} onBackClick={() => setChannelUrl(null)} />}
    </SendbirdProvider>
  );
}
```
`templates/starters-bp/react/src/screens/SignedInApp.tsx` wires the same two props to a sign-in flow. (source: https://sendbird.com/docs/chat/uikit/v3/react/essentials/handlers — "Session handlers": `configureSession` returns a `SessionHandler`, passed with `accessToken` to `SendbirdProvider`) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/types.ts#L47 — `ConfigureSessionTypes`; lines 205 and 208 `accessToken`, `configureSession` on `SendbirdProviderProps` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/context/hooks/useSendbird.tsx#L234-L241 — `setupSDK` with `configureSession(sdk)`, then `sdk.connect(userId, accessToken)` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/utils.ts#L93-L96 — `sdk.setSessionHandler` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/context/SendbirdProvider.tsx#L105-L125 — the connect effect depends on `[appId, userId]` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.0/src/modules/App/index.tsx#L20 — `AppProps` forwards `accessToken` only; same at v3.19.1 line 20) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication)

### After a reconnect: what `SendbirdProvider` and `GroupChannel` do
This describes 3.19.1 as the public source shows it; it is not a documented contract.

1. `SendbirdProvider` registers a Chat SDK `ConnectionHandler`. `onDisconnected` and `onReconnectStarted` set its `isOnline` flag to false, `onReconnectSucceeded` sets it back to true, and `onReconnectFailed` calls `sdk.reconnect()` again. A browser `online` event also calls `sdk.reconnect()` when the connection is not `OPEN`.
2. While `isOnline` is false, `GroupChannel` shows a connection status line under the input. The input is disabled only when the Chat SDK's local cache is off; with the cache on (the React UIKit default) it stays enabled.
3. `GroupChannelProvider` re-runs its `getChannel` effect when `isOnline` changes. If the earlier fetch failed during the disconnect, or the SDK instance changed, it fetches the channel again; otherwise it keeps the loaded channel. This recovery was fixed in 3.18.2, so stay on 3.18.2 or later.
4. The message list comes from `useGroupChannelMessages` in `@sendbird/uikit-tools`, which wraps the Chat SDK's message collection; `GroupChannelProvider` itself does not reload the list on reconnect.

To show your own connection banner, read the state with `useConnectionState()`:

```tsx
import { ConnectionState } from '@sendbird/chat';
import { useConnectionState } from '@sendbird/uikit-react/hooks/useConnectionState';

function ConnectionBanner() {
  const state = useConnectionState();
  if (state === ConnectionState.OPEN) return null;
  return <div role="status">{state === ConnectionState.CONNECTING ? 'Reconnecting…' : 'Offline'}</div>;
}
// Render <ConnectionBanner /> anywhere inside <SendbirdProvider>.
```

3.20.0 adds a modal that counts down while the server delays a connection, and a `renderConnectionDelayedModal` prop on `SendbirdProvider` / `App` to replace it (it receives `retryAfter` in seconds). It is not in 3.19.1.

(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/hooks/useOnlineStatus.ts lines 20-37 and 58-74 ; src/lib/Sendbird/context/SendbirdProvider.tsx:170 ; src/modules/GroupChannel/components/GroupChannelUI/GroupChannelUIView.tsx:158 ; src/modules/GroupChannel/components/MessageInputWrapper/MessageInputWrapperView.tsx:114-116 ; src/modules/GroupChannel/context/GroupChannelProvider.tsx:212,264-291 ; src/hooks/useConnectionState.ts:8-31 ; @sendbird/uikit-react@3.19.1 types/hooks/useConnectionState.d.ts:1-2 ; CHANGELOG.md v3.18.2, v3.20.0)

## React Native (`@sendbird/uikit-react-native`)
Install the package + its required peers (foundation, chat, and native modules — see the quickstart). Wrap the app in the container:
```tsx
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { createMMKV } from 'react-native-mmkv';

const mmkv = createMMKV(); // react-native-mmkv v4; v2/v3 use `new MMKV()`

<SendbirdUIKitContainer
  appId={APP_ID}
  chatOptions={{ localCacheStorage: mmkv }}   // required: the container throws without it (see hosts/react-native.md)
  platformServices={platformServices}   // built from the SDK's createNative*Service factories — see docs/sample
>
  {/* fragments / navigation */}
</SendbirdUIKitContainer>
```
`platformServices` (clipboard, notification, file, media, …) must be constructed per the quickstart; do not guess the factory calls. (source: sendbird-uikit-react-native sample/src/App.tsx + docs-validation SendbirdUIKitContainer.tsx)

### Session tokens: `connect(userId, { accessToken })` and `onInitialized`
`SendbirdUIKitContainer` initializes the Chat SDK but does not connect. Your app connects with the `connect` function of the `useConnection()` hook, from a component inside the container.

1. Your server issues the access or session token for the user, and the app fetches it after its own sign-in. Never ship the Platform API token or a fixed user token in the app.
2. Call `connect(userId, { accessToken })`. UIKit passes the token to the Chat SDK's `connect(userId, accessToken)`.
3. For renewal, set a Chat SDK `SessionHandler` in `chatOptions.onInitialized`. The container calls `onInitialized` right after `SendbirdChat.init`, before any connect, and uses the instance it returns, so call `setSessionHandler` there and return the same instance. The container initializes again when `appId` changes and calls `onInitialized` again, and only then. The handler therefore lives across sign-in and sign-out, so it must read the signed-in user and your token call at call time (the example below asks your auth store for the user), not a React state value captured when `App` rendered: a captured value stays `null` after sign-in and the first renewal gives up the session. In `onSessionTokenRequired`, fetch a new token and call `resolve(token)`, call `resolve(null)` to give up, or `reject(error)` on failure. In `onSessionClosed`, send the user back to your sign-in screen. See knowledge/curated/js/products/auth.md for when the SDK asks for a new token.

```tsx
import { SessionHandler } from '@sendbird/chat';
import { SendbirdUIKitContainer, useConnection } from '@sendbird/uikit-react-native';
import { createMMKV } from 'react-native-mmkv';

// Your app's call to your own server, which issues the token with the Platform API.
declare function fetchSessionToken(userId: string): Promise<string>;
// The user your app signed in, or null after sign-out.
declare function getSignedInUserId(): string | null;

const mmkv = createMMKV();

function createSessionHandler() {
  const handler = new SessionHandler();
  handler.onSessionTokenRequired = (resolve, reject) => {
    const userId = getSignedInUserId();
    if (!userId) return resolve(null);
    fetchSessionToken(userId).then(resolve, reject);
  };
  handler.onSessionClosed = () => {
    // route to your sign-in screen
  };
  return handler;
}

export function App() {
  return (
    <SendbirdUIKitContainer
      appId={APP_ID}
      chatOptions={{
        localCacheStorage: mmkv,
        onInitialized: (sdk) => {
          sdk.setSessionHandler(createSessionHandler()); // before any connect
          return sdk;
        },
      }}
      platformServices={platformServices}
    >
      {/* screens */}
    </SendbirdUIKitContainer>
  );
}

// In a component inside the container, after your own sign-in returned the user ID and a token.
export function useSendbirdSignIn() {
  const { connect } = useConnection();
  return (userId: string, accessToken: string) => connect(userId, { accessToken });
}
```
`templates/starters-bp/react-native` does the same in `App.tsx` and `src/sendbird/SessionBridge.tsx`. (source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/authentication — `connect('USER_ID', { nickname, accessToken })` from `useConnection()`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/hooks/useConnection.ts#L10 — `ConnectOptions` `{ nickname?, accessToken? }`; lines 32-36 pass `opts?.accessToken` to `sdk.connect` ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L87-L91 — `chatOptions.onInitialized`; lines 296-314 call it right after `SendbirdChat.init` and keep the returned instance; lines 169 and 181 initialize on mount and again on an `appId` change) (source: https://sendbird.com/docs/chat/uikit/v3/react-native/core-components/sendbirduikitcontainer — `chatOptions` lists `onInitialized`) (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication — `SessionHandler` must be set before connecting; `setSessionHandler`)

The customization sections below cite `@sendbird/uikit-react-native` 3.12.10 and `@sendbird/uikit-react-native-foundation` 3.12.10. Both packages ship their TypeScript `src/`, which is identical to `packages/*/src` in the public repo at tag `v3.12.10`, so the line numbers apply to either. Screens are built from fragments: `createGroupChannelFragment(modules?)` returns a component, and the optional `modules` object replaces parts of the screen (`Header`, `MessageList`, `Input`, `StatusEmpty`, `StatusLoading`, …). Call the factory once, outside your component.

### Customize how messages render (`renderMessage`)
The group channel fragment's `renderMessage(props)` replaces the bubble for each message. Return `GroupChannelMessageRenderer` (exported from the package root) with the same props for messages you don't customize. The props include `message`, `prevMessage`, `nextMessage`, `channel`, `focused`, `onPress`, and `onLongPress`. For a file message, `onPress` opens the file and `onLongPress` opens the message menu; for a failed message, `onPress` resends it. Wire both to your own touchable so a custom bubble keeps those actions.

```tsx
import { Pressable, Text } from 'react-native';
import { createGroupChannelFragment, GroupChannelMessageRenderer } from '@sendbird/uikit-react-native';

const GroupChannelFragment = createGroupChannelFragment();

function ChannelScreen({ onBack, onOpenSettings }: { onBack: () => void; onOpenSettings: () => void }) {
  return (
    <GroupChannelFragment
      channel={channel}
      onChannelDeleted={onBack}
      onPressHeaderLeft={onBack}
      onPressHeaderRight={onOpenSettings}
      renderMessage={(props) => {
        const { message } = props;
        if (message.isFileMessage() && message.type === 'application/pdf') {
          return (
            <Pressable onPress={props.onPress} onLongPress={props.onLongPress}>
              <Text>{`PDF: ${message.name}`}</Text>
            </Pressable>
          );
        }
        return <GroupChannelMessageRenderer {...props} />;
      }}
    />
  );
}
```

The fragment adds the typing-indicator bubble under the newest message itself, so you don't render it in `renderMessage`. `messageListQueryParams` (for example `customTypesFilter`) filters which messages load at all.

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/fragments/createGroupChannelFragment.tsx lines 47-76 and 204-212 — your `renderMessage` result, or `GroupChannelMessageRenderer`, wrapped with the typing bubble ; @sendbird/uikit-react-native@3.12.10 src/domain/groupChannel/types.ts:27-69 `GroupChannelProps['Fragment']` (`renderMessage` at 41, `messageListQueryParams` at 66), 205-213 `GroupChannelModule` ; src/components/ChannelMessageList/index.tsx:75-92 `renderMessage` props, 158-165, 465-485 (what `onPress` / `onLongPress` do) ; src/index.ts:12,30 ; https://sendbird.com/docs/chat/uikit/v3/react-native/group-channel-screens/chat-in-a-group-channel)

### Message menu (long press)
A long press opens a bottom sheet. `renderMessage` receives that sheet as `bottomSheetItem` (its `sheetItems` are the menu rows) together with the `onLongPress` that opens it; a pending message gets neither. To change the rows, open your own copy of the sheet with `useBottomSheet().openSheet(...)` from `@sendbird/uikit-react-native-foundation` and pass that as `onLongPress` to `GroupChannelMessageRenderer`. Because `useBottomSheet` is a hook, do this in a component that `renderMessage` returns.

```tsx
import { createGroupChannelFragment, GroupChannelMessageRenderer } from '@sendbird/uikit-react-native';
import { useBottomSheet } from '@sendbird/uikit-react-native-foundation';
import type { ComponentProps } from 'react';

type RendererProps = ComponentProps<typeof GroupChannelMessageRenderer>;
const GroupChannelFragment = createGroupChannelFragment();

function MessageWithReport({ onReport, ...props }: RendererProps & { onReport: () => void }) {
  const { openSheet } = useBottomSheet();
  const sheet = props.bottomSheetItem;
  const onLongPress = sheet
    ? () => openSheet({ ...sheet, sheetItems: [...sheet.sheetItems, { icon: 'info', title: 'Report', onPress: onReport }] })
    : props.onLongPress;
  return <GroupChannelMessageRenderer {...props} onLongPress={onLongPress} />;
}

function ChannelScreen({ onBack, onOpenSettings }: { onBack: () => void; onOpenSettings: () => void }) {
  return (
    <GroupChannelFragment
      channel={channel}
      onChannelDeleted={onBack}
      onPressHeaderLeft={onBack}
      onPressHeaderRight={onOpenSettings}
      renderMessage={(props) => <MessageWithReport {...props} onReport={() => { /* report props.message */ }} />}
    />
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/components/ChannelMessageList/index.tsx#L75-L93 — `renderMessage` props incl. `bottomSheetItem` ; the default sheet and `onLongPress` at lines 445-487) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native-foundation/src/ui/BottomSheet/index.tsx#L11-L21 — `BottomSheetItem`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native-foundation/src/ui/Dialog/index.tsx#L182-L186 — `useBottomSheet`) (source: https://sendbird.com/docs/chat/uikit/v3/react-native/group-channel-screens/chat-in-a-group-channel)

### Message input: attachments, disabling, placeholder, TextInput props
- Fragment props: `placeholder` (3.12.6+) replaces the send-mode placeholder in every state, including muted, frozen, and disabled; edit mode keeps the localized text. `partialTextInputProps` (3.10.2+) is typed `Partial<Pick<TextInputProps, 'autoCorrect'>>`, so `autoCorrect` is the only `TextInput` prop UIKit passes through; other `TextInput` props are not accepted.
- To disable the input for your own reason, replace the `Input` module with the exported `GroupChannelInput` and pass `inputDisabled`. UIKit still disables it on its own for a frozen channel or a muted user. A broadcast channel shows no input unless the current user is an operator.
- `AttachmentsButton` (a `ChannelInput` prop) replaces the attach button. It receives `onPress`, which opens UIKit's attachment sheet, and `disabled`. Return `null` from it to hide the button.
- Which items the attachment sheet offers comes from `uikitOptions.groupChannel.input` on `SendbirdUIKitContainer`: `camera.enablePhoto`, `camera.enableVideo`, `gallery.enablePhoto`, `gallery.enableVideo`, and `enableDocument`.

```tsx
import { createContext, useContext } from 'react';
import { Text, TouchableOpacity } from 'react-native';
import { createGroupChannelFragment, GroupChannelInput } from '@sendbird/uikit-react-native';

const ComposerLockedContext = createContext(false);

const GroupChannelFragment = createGroupChannelFragment({
  Input: (props) => {
    const locked = useContext(ComposerLockedContext);
    return (
      <GroupChannelInput
        {...props}
        inputDisabled={locked}
        AttachmentsButton={({ onPress, disabled }) => (
          <TouchableOpacity onPress={onPress} disabled={disabled}>
            <Text>Attach</Text>
          </TouchableOpacity>
        )}
      />
    );
  },
});

function ChannelScreen({ locked, onBack }: { locked: boolean; onBack: () => void }) {
  return (
    <ComposerLockedContext.Provider value={locked}>
      <GroupChannelFragment
        channel={channel}
        onChannelDeleted={onBack}
        onPressHeaderLeft={onBack}
        onPressHeaderRight={() => {}}
        placeholder={locked ? undefined : 'Ask us anything'}
        partialTextInputProps={{ autoCorrect: false }}
      />
    </ComposerLockedContext.Provider>
  );
}
```

The example leaves `placeholder` unset while locked, so the localized disabled text (`LABELS.CHANNEL_INPUT_PLACEHOLDER_DISABLED`) shows instead of the custom one.

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx lines 92-103 `uikitOptions` ; src/components/ChannelInput/index.tsx:55-99 `ChannelInputProps` (`AttachmentsButton` at 88, `partialTextInputProps` at 93, `placeholder` at 95-98), 181 ; src/components/ChannelInput/SendInput.tsx:177-182,204 ; src/components/ChannelInput/AttachmentsButton.tsx:6-9 ; src/domain/groupChannel/component/GroupChannelInput.tsx:9-31 ; src/domain/groupChannel/index.ts:3 ; src/domain/groupChannel/types.ts:56-57,109-121 ; src/fragments/createGroupChannelFragment.tsx:339-361 ; src/hooks/useChannelInputItems.ts:17-31,32,82,112,178 ; src/localization/StringSet.type.ts:295 ; CHANGELOG.md 3.10.2, 3.12.6)

### Channel list: custom item, filter, loading state
- `renderGroupChannelPreview({ channel, onPress, onLongPress })` replaces each row. `onPress` calls your `onPressChannel`, and `onLongPress` opens the row menu. The default row component is not exported from the package root, so a custom preview draws the whole row.
- `channelListQueryParams` takes the same Chat SDK filter fields as on the web (`includeEmpty`, `customTypesFilter`, `nicknameContainsFilter`, `channelNameContainsFilter`, …) plus `limit` and `order`.
- The list creates its collection once per SDK instance and user, so changing `channelListQueryParams` on a mounted fragment does not reload it.
- Pass `StatusLoading` and `StatusEmpty` modules to `createGroupChannelListFragment` to replace the loading and empty states.

```tsx
import { Pressable, Text } from 'react-native';
import { createGroupChannelListFragment } from '@sendbird/uikit-react-native';

const GroupChannelListFragment = createGroupChannelListFragment({
  StatusLoading: () => <Text>Loading channels…</Text>,
  StatusEmpty: () => <Text>No channels yet.</Text>,
});

function ChannelListScreen({ onOpen, onCreate }: { onOpen: (url: string) => void; onCreate: () => void }) {
  return (
    <GroupChannelListFragment
      onPressChannel={(channel) => onOpen(channel.url)}
      onPressCreateChannel={onCreate}
      channelListQueryParams={{ includeEmpty: false, customTypesFilter: ['support'] }}
      renderGroupChannelPreview={({ channel, onPress, onLongPress }) => (
        <Pressable onPress={onPress} onLongPress={onLongPress}>
          <Text>{channel.name}</Text>
        </Pressable>
      )}
    />
  );
}
```

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/fragments/createGroupChannelListFragment.tsx lines 30-33, 41-46, 54, 84-89 ; src/domain/groupChannelList/types.ts:11-30,35-39,66-73 ; src/domain/groupChannelList/component/GroupChannelListList.tsx:31-69 ; src/index.ts:33 ; @sendbird/uikit-tools@0.1.5 (the exact version `@sendbird/uikit-react-native` 3.12.10 depends on) dist/esm/hooks/useGroupChannelList/index.js:91-97 — the collection is created when `sdk` or the current user ID changes ; https://sendbird.com/docs/chat/uikit/v3/react-native/group-channel-screens/list-channels)

### Channel header
Replace the `Header` module. The component receives `onPressHeaderLeft`, `onPressHeaderRight`, and `shouldHideRight` (true when the screen was opened from message search), and can read `headerTitle` and `channel` from `GroupChannelContexts.Fragment`. `Header` and `Icon` come from the foundation package.

```tsx
import { useContext } from 'react';
import { createGroupChannelFragment, GroupChannelContexts } from '@sendbird/uikit-react-native';
import { Header, Icon } from '@sendbird/uikit-react-native-foundation';

const GroupChannelFragment = createGroupChannelFragment({
  Header: ({ onPressHeaderLeft, onPressHeaderRight, shouldHideRight }) => {
    const { headerTitle } = useContext(GroupChannelContexts.Fragment);
    const hideRight = shouldHideRight();
    return (
      <Header
        title={headerTitle}
        left={<Icon icon={'arrow-left'} />}
        onPressLeft={onPressHeaderLeft}
        right={hideRight ? null : <Icon icon={'info'} />}
        onPressRight={hideRight ? undefined : onPressHeaderRight}
      />
    );
  },
});
```

To change every UIKit header at once (for example to hand them to React Navigation), pass `styles.HeaderComponent` to `SendbirdUIKitContainer` instead; the default headers render through it.

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/domain/groupChannel/component/GroupChannelHeader.tsx lines 11-51 ; src/domain/groupChannel/types.ts:70-74,143-151 ; src/domain/groupChannel/index.ts:8 ; src/containers/SendbirdUIKitContainer.tsx:107-113,252 ; @sendbird/uikit-react-native-foundation@3.12.10 src/ui/Header/index.tsx:12-25 `HeaderProps` ; src/index.ts:7,33 `Icon`, `Header` ; https://sendbird.com/docs/chat/uikit/v3/react-native/customization/sendbirduikitcontainer)

### Start a 1:1 chat from a button (no channel list)
Get the SDK instance with `useSendbirdChat()`, create the channel with `isDistinct: true`, and navigate to a screen that loads the channel by URL with `useGroupChannel(sdk, channelUrl)` from `@sendbird/uikit-chat-hooks` and renders the group channel fragment. This is how Sendbird's public sample builds its `GroupChannel` route: React Navigation passes `{ channelUrl }` as the route params. Keep the button disabled until `currentUser` from `useSendbirdChat()` is set: UIKit's `useConnection().connect` sets it once connect has completed and `disconnect` clears it, so the create call never runs before connect. For a push tap, read the channel URL with `parseSendbirdNotification` (knowledge/curated/js/cross-cutting/push.md, "React Native: opening a channel from a push tap") and navigate to the same route.

```tsx
import React from 'react';
import { Button } from 'react-native';
import { createGroupChannelFragment, useSendbirdChat } from '@sendbird/uikit-react-native';
import { useGroupChannel } from '@sendbird/uikit-chat-hooks';

// onOpen: for example (url) => navigation.navigate('GroupChannel', { channelUrl: url })
export function ChatWithSellerButton({ sellerUserId, onOpen }: { sellerUserId: string; onOpen: (channelUrl: string) => void }) {
  const { sdk, currentUser } = useSendbirdChat();
  return (
    <Button
      title="Chat with seller"
      disabled={!currentUser} // set only after UIKit's connect has completed
      onPress={async () => {
        const created = await sdk.groupChannel.createChannel({ invitedUserIds: [sellerUserId], isDistinct: true });
        onOpen(created.url);
      }}
    />
  );
}

const GroupChannelFragment = createGroupChannelFragment();

// The screen behind the 'GroupChannel' route.
export function GroupChannelScreen({ channelUrl, onBack }: { channelUrl: string; onBack: () => void }) {
  const { sdk } = useSendbirdChat();
  const { channel } = useGroupChannel(sdk, channelUrl);
  if (!channel) return null;
  return (
    <GroupChannelFragment
      channel={channel}
      onChannelDeleted={onBack}
      onPressHeaderLeft={onBack}
      onPressHeaderRight={() => {}}
    />
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/sample/src/screens/uikit/groupChannel/GroupChannelScreen.tsx#L68-L98 — `useGroupChannel(sdk, params.channelUrl)` and the fragment's handlers) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/sample/src/libs/navigation.ts#L102-L108 — the `GroupChannel` route takes `channelUrl`) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/contexts/SendbirdChatCtx.tsx#L44-L47 — `currentUser?: SendbirdUser` in the context ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/hooks/useConnection.ts#L32-L103 — `connect` calls `setCurrentUser(user)` after `sdk.connect`, `disconnect` sets it to `undefined`) (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/hooks/useContext.d.ts:4 ; lib/typescript/src/domain/groupChannel/types.d.ts:11-16 — required `channel`, `onChannelDeleted`, `onPressHeaderLeft`, `onPressHeaderRight` ; @sendbird/uikit-chat-hooks 3.12.9 lib/typescript/src/channel/useGroupChannel.d.ts:7) (source: knowledge/curated/js/products/chat.md — Create and list group channels)

### Threads
Turn threads on with `uikitOptions={{ groupChannel: { replyType: 'thread', threadReplySelectType: 'thread' } }}` on `SendbirdUIKitContainer`; `threadReplySelectType` (`'thread'` or `'parent'`) decides what a tap on a reply in the channel opens. The thread screen is its own fragment: create it with `createGroupChannelThreadFragment()` and put it on a screen of your navigator. The channel fragment's `onPressReplyMessageInThread(parentMessage, startingPoint)` is where you navigate to that screen. The thread fragment needs `channel`, `parentMessage`, `onParentMessageDeleted`, `onChannelDeleted`, and `onPressHeaderLeft`. Threads are one level deep, in group and supergroup channels only.

```tsx
import { createGroupChannelThreadFragment } from '@sendbird/uikit-react-native';
import type { FileMessage, UserMessage } from '@sendbird/chat/message';

const GroupChannelThreadFragment = createGroupChannelThreadFragment();

function ThreadScreen({ parentMessage, onBack }: { parentMessage: UserMessage | FileMessage; onBack: () => void }) {
  return (
    <GroupChannelThreadFragment
      channel={channel}
      parentMessage={parentMessage}
      onParentMessageDeleted={onBack}
      onChannelDeleted={onBack}
      onPressHeaderLeft={onBack}
    />
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react-native/features/message-threading/threads) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannelThread/types.ts ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannel/types.ts#L28-L34 — `onPressReplyMessageInThread` ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/index.ts#L41)

### Channel settings menu items
`createGroupChannelSettingsFragment()` returns a fragment whose `menuItemsCreator(defaultMenuItems)` receives the default rows as `MenuBarProps` objects (`icon`, `name`, `onPress`, and optional `actionLabel`, `actionItem`, `visible`, `disabled`) and returns the rows to show. Add, remove, or reorder rows there. The fragment's required props are `channel`, `onPressHeaderLeft`, `onPressMenuModeration`, `onPressMenuMembers`, and `onPressMenuLeaveChannel`.

```tsx
import { Share } from 'react-native';
import { createGroupChannelSettingsFragment } from '@sendbird/uikit-react-native';

const GroupChannelSettingsFragment = createGroupChannelSettingsFragment();

function SettingsScreen({ go }: { go: (route: 'back' | 'moderation' | 'members' | 'list') => void }) {
  return (
    <GroupChannelSettingsFragment
      channel={channel}
      onPressHeaderLeft={() => go('back')}
      onPressMenuModeration={() => go('moderation')}
      onPressMenuMembers={() => go('members')}
      onPressMenuLeaveChannel={() => go('list')}
      menuItemsCreator={(items) => [
        { icon: 'channels', name: 'Share channel', onPress: () => Share.share({ message: channel.url }) },
        ...items,
      ]}
    />
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react-native/group-channel-screens/configure-group-channel-settings) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannelSettings/types.ts#L8-L31 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native-foundation/src/ui/MenuBar/index.tsx#L13-L27 — `MenuBarProps`)

### Keyboard covering the input
The message input of the group channel fragment is wrapped in React Native's `KeyboardAvoidingView`. When something sits above the fragment, such as a navigator header, pass its height as `keyboardAvoidOffset` so the input ends up directly above the keyboard; the docs describe the value as the adjusted y position of the keyboard. The thread fragment takes the same prop. (source: https://sendbird.com/docs/chat/uikit/v3/react-native/group-channel-screens/chat-in-a-group-channel) (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannel/types.ts#L49 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/components/ChannelInput/index.tsx#L3 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/domain/groupChannelThread/types.ts#L43)

Anything rendered above the fragment on the same screen counts, not only a navigator header: a button row such as "Invite users", a banner, or a safe-area wrapper that pads the top. On iOS the input's `KeyboardAvoidingView` uses the `'padding'` behavior with a vertical offset of `keyboardAvoidOffset` minus the bottom safe-area inset, and React Native measures that view's position from `onLayout`, which is relative to its parent inside the fragment rather than to the screen. So without the offset the input and the newest messages stay behind the keyboard by the height of what sits above the fragment: the user cannot see what they type, and messages that arrive while the keyboard is open look as if they never came. Keep the fragment at the top of its screen and put the extra action in the fragment's header (`onPressHeaderRight`, or a custom `Header`), or measure the element above it and pass that height:

```tsx
import { useState } from 'react';
import { Button, View } from 'react-native';
import { createGroupChannelFragment } from '@sendbird/uikit-react-native';

const GroupChannelFragment = createGroupChannelFragment();

function ChannelScreen({ onBack, openInvite }: { onBack: () => void; openInvite: () => void }) {
  const [barHeight, setBarHeight] = useState(0);
  return (
    <View style={{ flex: 1 }}>
      <View onLayout={(e) => setBarHeight(e.nativeEvent.layout.height)}>
        <Button title="Invite users" onPress={openInvite} />
      </View>
      <GroupChannelFragment
        channel={channel}
        onChannelDeleted={onBack}
        onPressHeaderLeft={onBack}
        onPressHeaderRight={openInvite}
        keyboardAvoidOffset={barHeight}
      />
    </View>
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/components/ChannelInput/index.tsx#L102 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/components/ChannelInput/index.tsx#L159-L161 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/domain/groupChannel/types.ts#L49) (source: https://github.com/facebook/react-native/blob/v0.87.1/packages/react-native/Libraries/Components/Keyboard/KeyboardAvoidingView.js#L116 ; https://github.com/facebook/react-native/blob/v0.87.1/packages/react-native/Libraries/Components/Keyboard/KeyboardAvoidingView.js#L135)

## Pitfalls
- React: import `@sendbird/uikit-react/dist/index.css` or the UI renders unstyled.
- React: don't mix the drop-in `App` component with the granular `GroupChannelList`/`GroupChannel` components in the same tree — pick one composition style per screen.
- React: the package's shipped root `types/index.d.ts` lags the actual v3 component tree (it still lists `ChannelList` / `withSendBird`, a v2-era surface). Verify prop names against the subpath's real TSX source, not that file, before citing them.
- React: `renderFileUploadIcon` replaces the attach button and its file picker, not only the icon (see "Message input" above).
- React: pass `render*` props as functions that return an element, `renderMessageInput={() => <MyInput />}`, not the component itself (`renderMessageInput={MyInput}`). `GroupChannelUIView` calls them as plain functions (`renderMessageInput?.()`) and returns early for its loading and error states, so the hooks inside a component passed directly run as part of UIKit's render on some renders only, and React reports a change in the order of hooks. Wrap the arrow function in `useCallback` if you want a stable reference. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannel/components/GroupChannelUI/GroupChannelUIView.tsx#L117-L152 — early returns, then `renderChannelHeader?.(...)` and `renderMessageInput?.()`; prop types `() => React.ReactElement` at line 43)
- React Native: `platformServices` is required; follow the quickstart's factory setup exactly.
- React Native: changing `channelListQueryParams` on a mounted channel list fragment does not reload the list (see "Channel list" above).
- App ID from env; access/session tokens are secrets — never hard-code. Pass them as described in "Session tokens" (React: `accessToken` + `configureSession` on `SendbirdProvider`; React Native: `connect(userId, { accessToken })` + a `SessionHandler` set in `chatOptions.onInitialized`).

## Related
- React repo: https://github.com/sendbird/sendbird-uikit-react
- React Native repo: https://github.com/sendbird/sendbird-uikit-react-native
- Underlying Chat: knowledge/curated/js/products/chat.md
