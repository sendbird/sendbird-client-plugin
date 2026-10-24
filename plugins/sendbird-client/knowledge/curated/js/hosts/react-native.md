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

Run this only from the `'change'` listener. Do not pass `AppState.currentState` to a function typed `(status: AppStateStatus)`: in React Native 0.87.1 the types the package exports declare `currentState: null | undefined | string`, so tsc stops with TS2345 ("Argument of type 'string' is not assignable to parameter of type 'AppStateStatus'"). Right after `connect` resolves the app is in the foreground, so there is nothing to apply then. (source: https://unpkg.com/react-native@0.87.1/package.json — `exports["."].types` is `./types_generated/index.d.ts`; https://unpkg.com/react-native@0.87.1/types_generated/Libraries/AppState/AppState.d.ts line 69 `currentState: null | undefined | string`, line 28 `AppStateStatus`)

To also react to connectivity, the docs combine this with `@react-native-community/netinfo` into a single "active AND reachable" state. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4398,4403 ; @sendbird/uikit-react-native@3.12.9 src/contexts/SendbirdChatCtx.tsx:165-168)

## Keyboard over the message input (Chat SDK screens)

A screen you build yourself on the Chat SDK does not move its message input above the keyboard: React Native leaves that to the screen. Make the root of every screen with an input at the bottom (the conversation, a thread) a `KeyboardAvoidingView` with `behavior="padding"`, not a plain `View`. On iOS a plain `View` leaves the input and its Send button behind the keyboard; on Android 15 and later an edge-to-edge window no longer resizes for the keyboard, and React Native 0.86 made `KeyboardAvoidingView` work there, so Android gets `'padding'` too (React Native 0.85 and older on Android: no behavior, the window resizes). Set `keyboardVerticalOffset` to the height of whatever is drawn above the view from outside it, such as a navigator header (`useHeaderHeight()` in React Navigation); a header the screen draws inside the view counts as 0. `templates/js/react-native/chat/KeyboardAvoidingScreen.tsx` is that root, type-checked by the template compile check; the UIKit conversation has its own rule (`keyboardAvoidOffset`, knowledge/curated/js/products/uikit.md "Keyboard covering the input"). (source: https://reactnative.dev/docs/keyboardavoidingview ; https://reactnative.dev/blog/2026/06/11/react-native-0.86 ; a 2026-10-24 run-check of a Chat SDK demo on the iOS simulator, whose conversation screen had a plain View root)

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

## Native permissions (UIKit)

The UIKit native modules page lists the permissions UIKit's features need. Declaring them is not the same as being granted them at runtime.

- Android, in `android/app/src/main/AndroidManifest.xml`: `RECORD_AUDIO` (voice messages), `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` and `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion="28"` (attachments), `CAMERA`, and `POST_NOTIFICATIONS` (notifications on Android 13 and later).
- iOS, in `Info.plist`: Camera, Microphone, Photo Library, and Photo Library Additions usage descriptions. If you use `react-native-permissions`, run `pod install` after changing them.

On Android 13 and later, notifications appear only after the user grants `POST_NOTIFICATIONS` at runtime. UIKit's notification service has `hasPushPermission()` and `requestPushPermission()`; on Android, the service made by `createNativeNotificationService` checks and requests it with `react-native-permissions` (`checkNotifications`, `requestNotifications`), and on iOS it asks Firebase Messaging.

```ts
const granted = (await platformServices.notification.hasPushPermission())
  || (await platformServices.notification.requestPushPermission());
```

(source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/native-modules) (source: https://developer.android.com/develop/ui/views/notifications/notification-permission) (source: @sendbird/uikit-react-native 3.12.9 lib/typescript/src/platform/types.d.ts:17-18 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/platform/createNotificationService.native.ts#L63-L92)

## Sending a file (no `File` in React Native)

React Native has no `File` type, and the docs say a `File` or `Blob` passed as `file` may not work there. Pass an object with all three fields of the SDK's `FileInfo` interface: `name`, `uri`, and `type` (the MIME type, for example `audio/m4a` for a recording). `FileCompat`, the type of `file`, is `File | Blob | FileInfo`.

```ts
function sendRecording(uri: string) {
  channel
    .sendFileMessage({ file: { name: 'recording.m4a', uri, type: 'audio/m4a' } })
    .onSucceeded((message) => {})
    .onFailed((error) => {});
}
```

(source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/environment-specific-implementation — "File message without File" ; @sendbird/chat@4.22.13 lib/__definition.d.ts:1733-1742 `FileCompat`, `FileInfo`, :1792 `FileMessageCreateParams.file`)

## Version compatibility checklist

- `@sendbird/uikit-react-native@3.12.9` declares peers `@sendbird/chat ^4.20.2`, `react-native >=0.65.0`, `react >=17.0.2`, and `react-native-mmkv >=2.0.0`. Install `@sendbird/chat` yourself and keep it current within 4.x: 4.20.5 fixes a `hasBot of undefined` error when loading cached channels, and 4.22.10 fixes file uploads on Expo SDK 56+ `fetch`. (source: @sendbird/uikit-react-native@3.12.9 package.json peerDependencies ; @sendbird/chat CHANGELOG.md v4.20.5, v4.22.10)
- React Native 0.71 or lower also needs `@sendbird/react-native-scrollview-enhancer`. (source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/installation)
- Framework support landed in these UIKit releases: RN 0.79 (3.9.3), RN 0.81 via `react-native-nitro-sound` (3.11.0), Expo SDK 54 `expo-video`/`expo-audio` (3.11.1) and `expo-file-system` (3.11.3), and Expo 56 media-library saves (3.12.7). Upgrade UIKit before a framework bump. (source: github.com/sendbird/sendbird-uikit-react-native CHANGELOG.md @ v3.12.9)
- Pick each native peer's version from the project's `react-native` version, not the newest release. For example, `@react-native-documents/picker@12.0.2` declares `react-native >=0.79.0`, so a project on 0.74 needs an older picker. Check with `npm view <package>@<range> peerDependencies`, and never install with `--legacy-peer-deps`: a later clean `npm install` then fails with `ERESOLVE`. (source: `npm view @react-native-documents/picker@12.0.2 peerDependencies` ; npm ERESOLVE output from a clean install on react-native 0.74.5)
- The UIKit packages ship JavaScript/TypeScript only (no `android/` or `ios/` sources); native code comes from the peer modules you install, so check those for native build requirements. (source: @sendbird/uikit-react-native@3.12.9 npm package contents)
- Native modules with a privacy-manifest resource bundle can stop an Xcode 27 build: `react-native-image-picker` 8.2.1 and 8.3.0 declare `s.platform = :ios, "9.0"` and a `RNImagePickerPrivacyInfo` resource bundle, and React Native's `react_native_post_install` raises only the pods' library targets, so the bundle target keeps iOS 9.0 and xcodebuild fails with "The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 9.0, but the range of supported deployment target versions is 15.0 to 27.1.x". The plugin's React Native starters raise every pod target below `min_ios_version_supported` in the Podfile's `post_install`, after `react_native_post_install`; a project that started elsewhere and adds such a module needs the same loop (see `templates/starters/react-native/ios/Podfile`), then `pod install`. (source: react-native-image-picker 8.2.1 and 8.3.0 npm package `react-native-image-picker.podspec` ; react-native 0.87.1 `scripts/cocoapods/utils.rb` `updateOSDeploymentTarget` ; xcodebuild output from a 2026-10-24 run-check build with Xcode 27)

## Related

- UIKit: knowledge/curated/js/products/uikit.md
- AI Agent: knowledge/curated/js/products/ai-agent.md
- React host: knowledge/curated/js/hosts/react.md
