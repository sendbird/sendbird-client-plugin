<!-- last-verified-against: @sendbird/chat 4.22.13 / @sendbird/uikit-react 3.19.1 -->
<!-- status: populated -->
# js host — React (web)

> Host guidance. Detection and integration notes are conceptual; the multi-tab and autoscroll sections cite each SDK symbol. Verified 2026-09-30.

## Detection signals

- `react` + `react-dom` deps, `.jsx`/`.tsx`, web bundler (Vite/Next/CRA), no `react-native` dep.

## Integration notes

- Core chat via `@sendbird/chat`; prebuilt UI via `@sendbird/uikit-react`; AI Agent via `@sendbird/ai-agent-messenger-react`.
- UIKit/AI Agent React components need their CSS imported (e.g. `@sendbird/uikit-react/dist/index.css`).
- Manage handlers in `useEffect` cleanup; init `sb` once (module singleton / context), not per render.

## Multiple tabs or windows

If users open the same app in several tabs or windows, enable the Chat SDK's multi-tab support through `SendbirdProvider`'s `sdkInitParams`, which is passed through to `SendbirdChat.init()`. `supportMultipleTabs` is a Chat SDK option (4.20.6+), is off by default, and only applies when local caching is on. React UIKit already turns local caching on by default, so setting `localCacheEnabled` explicitly is optional.

```tsx
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';

<SendbirdProvider
  appId={APP_ID}
  userId={USER_ID}
  sdkInitParams={{ localCacheEnabled: true, supportMultipleTabs: true }}
>
  <GroupChannel channelUrl={CHANNEL_URL} />
</SendbirdProvider>
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/local-caching/overview-local-caching ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4815,4818 ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:120,161)

## Tall incoming messages (`autoscrollMessageOverflowToTop`)

By default, a newly received message scrolls the list to the bottom. With `autoscrollMessageOverflowToTop`, when a newly received message is taller than the message list viewport, UIKit scrolls to the top of that message instead, so its beginning stays visible. It only acts when the user was already at the bottom of the list. Set it as a `SendbirdProvider` (or `App`) prop; a `GroupChannel` prop overrides it per channel. Use the prop, not `uikitOptions.groupChannel`, which has no such field in 3.19.1.

```tsx
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';

<SendbirdProvider appId={APP_ID} userId={USER_ID} autoscrollMessageOverflowToTop>
  <GroupChannel channelUrl={CHANNEL_URL} />
</SendbirdProvider>
```

Requires `@sendbird/uikit-react` 3.17.6 or later for the provider-level prop to reach `GroupChannel`. (source: @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:164 ; @sendbird/uikit-react CHANGELOG.md v3.17.5, v3.17.6 ; github.com/sendbird/sendbird-uikit-react v3.19.1 src/modules/GroupChannel/context/GroupChannelProvider.tsx:224-238)

## Related

- Chat: knowledge/curated/js/products/chat.md
- UIKit: knowledge/curated/js/products/uikit.md
- React Native host: knowledge/curated/js/hosts/react-native.md
