<!-- status: populated -->
# React Native starter (best practice)

A small React Native (TypeScript) app with Sendbird Chat and UIKit for React Native wired the
recommended way: sign-in with a user ID, connect, the UIKit channel list and conversation, and
sign-out. It includes its `ios/` and `android/` native projects, so it runs on the iOS Simulator and
the Android Emulator. The practices it follows are listed in `../BEST_PRACTICES.md`.

## What is included

- `package.json` — exact versions: `@sendbird/chat` 4.22.13, `@sendbird/uikit-react-native` 3.12.10, React Native 0.87.1, and the native modules UIKit uses, each chosen so its peer range accepts React Native 0.87.1 (a plain `npm install` resolves without `--legacy-peer-deps`). They are the versions the UIKit for React Native sample uses with React Native 0.87.1 (`sample/package.json` on the public repository's `main`). `lodash` is listed because `@openspacelabs/react-native-zoomable-view`, which UIKit uses, imports it without declaring it (https://github.com/openspacelabs/react-native-zoomable-view/issues/160); without it Metro stops with "Unable to resolve module lodash".
- `ios/`, `android/` — the native projects of `../../starters/react-native` (React Native Community CLI template, `npx @react-native-community/cli@20.2.0 init StarterReactNative --version 0.87.1`, with the changes listed in that starter's `_README.md`), plus what UIKit's native modules need: in `ios/Podfile`, the react-native-permissions handlers for camera, microphone, and photo library, module maps for the Firebase pods (as in the UIKit sample's Podfile), and a raised deployment target for pods that declare iOS 9 to 12 (Xcode 27 builds iOS 15.0 or later only); the matching usage descriptions in `Info.plist`; and the permissions in `AndroidManifest.xml` (https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/native-modules).
- `App.tsx` — `SendbirdUIKitContainer` at the root (init, cache, theme, session handler) and the screen switch.
- `src/sendbird/SessionBridge.tsx` — connects and disconnects through UIKit's `useConnection`, and keeps the connection handler.
- `src/auth/session.ts` — the one app-wide session store; `src/auth/login.ts` — `onLoginSucceeded` / `onLogout` for your own sign-in.
- `src/screens/LoginScreen.tsx`, `HomeScreen.tsx`, `ChannelsScreen.tsx` (UIKit list and conversation fragments). On Android the conversation sits in a `KeyboardAvoidingView` with `padding`: UIKit's message input avoids the keyboard itself only on iOS (`packages/uikit-react-native/src/components/ChannelInput/index.tsx` at `v3.12.10`) and otherwise relies on the window resizing, which edge-to-edge (Android 15 and later) no longer does, so the keyboard would cover the input. React Native 0.86 made `KeyboardAvoidingView` work with `edgeToEdgeEnabled` (https://reactnative.dev/blog/2026/06/11/react-native-0.86).
- `src/sendbird/platformServices.ts` (native services, as in the public sample; without a Firebase app it uses a notification service with no push, so the app starts before the Firebase files are added), `config.ts`, `errors.ts`; `src/auth/token.ts`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `App.tsx:22` | One `SendbirdUIKitContainer` at the app root initializes the Chat SDK once. |
| BP02 | `src/sendbird/config.ts:3` | Reads `sendbirdAppId` from `app.json`; empty is reported on the sign-in screen (`src/screens/LoginScreen.tsx:32`). |
| BP03 | `src/auth/session.ts:49` | Connects only after `onLoginSucceeded(userId)` (`src/sendbird/SessionBridge.tsx:38`). |
| BP04 | `App.tsx:30` | `setSessionHandler` in `chatOptions.onInitialized`, before any connect; the handler asks `src/auth/token.ts:3` for a token (`src/sendbird/SessionBridge.tsx:14`). |
| BP05 | `src/sendbird/SessionBridge.tsx:38` | Connects with UIKit's `useConnection().connect`, so UIKit tracks the current user. |
| BP06 | `src/screens/HomeScreen.tsx:23` | The Channels button appears only after connect returns. |
| BP07 | `src/sendbird/SessionBridge.tsx:59` | A `ConnectionHandler` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `src/sendbird/SessionBridge.tsx:59` | Added while signed in under one identifier, removed on sign-out. |
| BP09 | `src/sendbird/SessionBridge.tsx:56` | UIKit's `disconnect()` unregisters this device's push token, then disconnects. |
| BP10 | `src/sendbird/platformServices.ts:48` | UIKit's connect registers the push token through the notification service (auto registration is on by default; `src/sendbird/SessionBridge.tsx:39`). |
| BP11 | `App.tsx:16` | An MMKV store as `chatOptions.localCacheStorage`; the container turns local caching on. |
| BP12 | `App.tsx:23` | `styles.theme` on the container. |
| BP13 | `src/sendbird/errors.ts:4` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`src/sendbird/SessionBridge.tsx:49`). |
| BP15 | `App.tsx:22` | The container also follows the app state (foreground and background) for the Chat SDK. |
| BP16 | `src/auth/session.ts:1` | One store; `Screens` (`App.tsx:43`) and `SessionBridge` read it. |
| BP17 | `src/screens/LoginScreen.tsx:39` | `testID` values (see below). |

Not applicable here: BP14 (SwiftUI).

How UIKit's `useConnection` handles push and the cache is read from its source:
`packages/uikit-react-native/src/hooks/useConnection.ts` at tag `v3.12.10` (connect registers the
push token when auto registration is on, disconnect unregisters it before `sdk.disconnect()`, and
a connect that fails with 400300, 400301, 400302, or 400310 clears the cached data).

## Set the App ID

Set `"sendbirdAppId": "<your App ID>"` in `app.json` and rebuild (Metro bundles it). The App ID is
not a secret; session and access tokens are, and never go into `app.json`.

## Run

```bash
npm install
cd ios && pod install && cd ..   # iOS only; again after adding a package with native code
npm start                        # Metro, in its own terminal
npm run ios                      # or: npm run android
```

Push needs your Firebase project: add `android/app/google-services.json` and
`ios/GoogleService-Info.plist`, and the Firebase setup steps in React Native Firebase's
installation guide (https://rnfirebase.io). Until then the app runs without push.

## Stable identifiers

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `src/screens/LoginScreen.tsx:39` |
| `sb_login_button` | Sign in button | `src/screens/LoginScreen.tsx:48` |
| `sb_app_id_missing` | missing App ID message | `src/screens/LoginScreen.tsx:33` |
| `sb_connection_status` | status text | `src/screens/HomeScreen.tsx:20` |
| `sb_open_channels` | Channels button | `src/screens/HomeScreen.tsx:24` |
| `sb_logout_button` | Sign out button | `src/screens/HomeScreen.tsx:25` |
| `sb_channel_list` | container of the UIKit channel list | `src/screens/ChannelsScreen.tsx:44` |
| `sb_message_input`, `sb_send_button` | not set | UIKit for React Native 3.12.10 sets no `testID` in its components. |

## Verified

Checked on 2026-10-16:

- `npm install` (no `--legacy-peer-deps`) and `tsc --noEmit` — pass.
- iOS: `pod install`, Debug build with Xcode 27.0 for an iOS 27.0 simulator, started with Metro —
  the sign-in screen shows.
- Android: `./gradlew assembleDebug`, started with Metro on an API 35 emulator — the sign-in screen
  shows; signing in with a test application connects (the server reports the user online), and
  the UIKit channel list opens.
- Not checked: push (no Firebase project).

Checked on 2026-10-17 with two users of a test application: user A signs in to the app, user B is a
Chat SDK script that opens a 1:1 channel with A and reads and writes it on the server.

- iOS (Xcode 27.0, iOS 27.0 simulator), Debug with Metro and Release (bundled JavaScript): sign in,
  the channel list, open the channel; A's message reaches B on the server and B's reply shows in
  the open channel.
- Android (API 35 emulator), Debug with Metro and `./gradlew assembleRelease`: the same steps.
  Before the `KeyboardAvoidingView` in `src/screens/ChannelsScreen.tsx`, the keyboard covered the
  message input and the newest messages on Android; with it, the input sits above the keyboard.

## Next steps

- Your sign-in: call `onLoginSucceeded(userId)` from `src/auth/login.ts` after it succeeds.
- Tokens: return a session token from your server in `src/auth/token.ts`
  (`knowledge/curated/js/products/auth.md`).
- Create channel and channel settings screens: the two placeholders in `src/screens/ChannelsScreen.tsx`.
- Push taps that open a channel: `knowledge/curated/js/cross-cutting/push.md`.
- Theme and strings: `knowledge/curated/js/cross-cutting/theme.md`.

(source: knowledge/curated/js/hosts/react-native.md)
(source: knowledge/curated/js/products/uikit.md)
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/hooks/useConnection.ts#L29-L104)
