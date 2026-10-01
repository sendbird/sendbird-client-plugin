<!-- last-verified-against: @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.9 -->
<!-- status: populated -->
# js uikit

> Verified against the public mirrors `sendbird/sendbird-uikit-react` and `sendbird/sendbird-uikit-react-native`. React and React Native templates type-checked against pinned and latest packages, including 3.19.1 and 3.12.9, on 2026-09-22. The GroupChannelList/GroupChannel prop sections below are verified against the `sendbird-uikit-react` repo's actual TSX source at `main` (verified 2026-09-29) — the package's own shipped `types/index.d.ts` is a stale/legacy export surface and does not match the runtime component tree, so props are cited from source, not from the package's `.d.ts`. Cite each symbol; do not add API from memory.
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

Read SDK connection/store state for advanced cases with `useSendbirdStateContext()` (exported for backward-compat; prefer driving UI through props above where possible). (source: `sendbird-uikit-react` src/lib/Sendbird/context/hooks/useSendbirdStateContext.tsx)

## React Native (`@sendbird/uikit-react-native`)
Install the package + its required peers (foundation, chat, and native modules — see the quickstart). Wrap the app in the container:
```tsx
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';

<SendbirdUIKitContainer
  appId={APP_ID}
  platformServices={platformServices}   // built from the SDK's createNative*Service factories — see docs/sample
>
  {/* fragments / navigation */}
</SendbirdUIKitContainer>
```
`platformServices` (clipboard, notification, file, media, …) must be constructed per the quickstart; do not guess the factory calls. (source: sendbird-uikit-react-native sample/src/App.tsx + docs-validation SendbirdUIKitContainer.tsx)

## Pitfalls
- React: import `@sendbird/uikit-react/dist/index.css` or the UI renders unstyled.
- React: don't mix the drop-in `App` component with the granular `GroupChannelList`/`GroupChannel` components in the same tree — pick one composition style per screen.
- React: the package's shipped root `types/index.d.ts` lags the actual v3 component tree (it still lists `ChannelList` / `withSendBird`, a v2-era surface). Verify prop names against the subpath's real TSX source, not that file, before citing them.
- React Native: `platformServices` is required; follow the quickstart's factory setup exactly.
- App ID from env; access/session tokens are secrets — never hard-code.

## Related
- React repo: https://github.com/sendbird/sendbird-uikit-react
- React Native repo: https://github.com/sendbird/sendbird-uikit-react-native
- Underlying Chat: knowledge/curated/js/products/chat.md
