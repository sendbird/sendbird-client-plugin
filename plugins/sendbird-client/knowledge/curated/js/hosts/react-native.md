<!-- last-verified-against: @sendbird/chat 4.22.13 / @sendbird/uikit-react-native 3.12.9 -->
<!-- status: populated -->
# js host — React Native

> Host guidance. Detection and integration notes are conceptual; the lifecycle, local cache, and compatibility sections cite each SDK symbol. Verified 2026-09-30.

## Detection signals

- `react-native` dep, `metro.config`, `ios/` + `android/` native folders, `react-native` imports (`View`, `Text`).

## Integration notes

- Core chat via `@sendbird/chat` (same as web); prebuilt UI via `@sendbird/uikit-react-native` (needs `platformServices` + native modules); AI Agent via `@sendbird/ai-agent-messenger-react-native` (needs `nativeModules` incl. `react-native-mmkv`).
- Native peers (mmkv, safe-area-context, clipboard, image/document pickers) must be installed + linked per the quickstart.
- Push: register the FCM/APNs token from the native layer via the chat SDK (see cross-cutting/push.md).

## App lifecycle (Chat SDK without UIKit)

The JS Chat SDK does not follow React Native app state by itself. Call `sb.setBackgroundState()` when the app goes to background (closes the WebSocket, keeps `currentUser` and cached data) and `sb.setForegroundState()` when it returns (re-establishes the WebSocket). If you skip `setBackgroundState()`, the OS can drop the socket while the SDK still thinks it is foreground, and your `MessageCollection` stops receiving events until the SDK reconnects. `SendbirdUIKitContainer` from `@sendbird/uikit-react-native` already does this wiring internally, so add it yourself only in Chat-SDK-only apps.

```ts
import { AppState } from 'react-native';

const subscription = AppState.addEventListener('change', (status) => {
  if (status === 'active') sb.setForegroundState();
  else if (status === 'background') sb.setBackgroundState();
});
// On teardown (e.g. logout): subscription.remove();
```

To also react to connectivity, the docs combine this with `@react-native-community/netinfo` into a single "active AND reachable" state. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4398,4403 ; @sendbird/uikit-react-native@3.12.9 src/contexts/SendbirdChatCtx.tsx:165-168)

## UIKit container: local cache storage

`SendbirdUIKitContainer` requires `chatOptions.localCacheStorage` and throws without it. Pass an MMKV instance (AsyncStorage still works but is deprecated). UIKit hands it to the Chat SDK and always enables local caching. Don't clear or edit that MMKV store yourself, for example with `mmkv.clearAll()`, because it can corrupt the SDK's cache.

```tsx
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { createMMKV } from 'react-native-mmkv';

const mmkv = createMMKV(); // react-native-mmkv v4; on v2/v3 (the docs' example) use `new MMKV()`

<SendbirdUIKitContainer appId={APP_ID} chatOptions={{ localCacheStorage: mmkv }} platformServices={platformServices}>
  {/* app */}
</SendbirdUIKitContainer>
```

(source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/send-first-message ; @sendbird/uikit-react-native@3.12.9 src/containers/SendbirdUIKitContainer.tsx:90,154-158 ; https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation ; react-native-mmkv@4.3.2 lib/index.d.ts:1,3 — `MMKV` is a type only in v4, `createMMKV()` makes the instance)

## Version compatibility checklist

- `@sendbird/uikit-react-native@3.12.9` declares peers `@sendbird/chat ^4.20.2`, `react-native >=0.65.0`, `react >=17.0.2`, and `react-native-mmkv >=2.0.0`. Install `@sendbird/chat` yourself and keep it current within 4.x: 4.20.5 fixes a `hasBot of undefined` error when loading cached channels, and 4.22.10 fixes file uploads on Expo SDK 56+ `fetch`. (source: @sendbird/uikit-react-native@3.12.9 package.json peerDependencies ; @sendbird/chat CHANGELOG.md v4.20.5, v4.22.10)
- React Native 0.71 or lower also needs `@sendbird/react-native-scrollview-enhancer`. (source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/installation)
- Framework support landed in these UIKit releases: RN 0.79 (3.9.3), RN 0.81 via `react-native-nitro-sound` (3.11.0), Expo SDK 54 `expo-video`/`expo-audio` (3.11.1) and `expo-file-system` (3.11.3), and Expo 56 media-library saves (3.12.7). Upgrade UIKit before a framework bump. (source: github.com/sendbird/sendbird-uikit-react-native CHANGELOG.md @ v3.12.9)
- The UIKit packages ship JavaScript/TypeScript only (no `android/` or `ios/` sources); native code comes from the peer modules you install, so check those for native build requirements. (source: @sendbird/uikit-react-native@3.12.9 npm package contents)

## Related

- UIKit: knowledge/curated/js/products/uikit.md
- AI Agent: knowledge/curated/js/products/ai-agent.md
- React host: knowledge/curated/js/hosts/react.md
