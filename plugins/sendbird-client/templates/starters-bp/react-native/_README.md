<!-- status: populated -->
# React Native starter (best practice)

A small React Native (TypeScript) app with Sendbird Chat and UIKit for React Native wired the
recommended way: sign-in with a user ID, connect, the UIKit channel list and conversation, and
sign-out. It is the JavaScript part of the app: add it to a React Native project that has its
`ios/` and `android/` folders (for example one made with the React Native CLI for 0.81), then install
the native modules. The practices it follows are listed in `../BEST_PRACTICES.md`.

## What is included

- `package.json` — exact versions: `@sendbird/chat` 4.22.13, `@sendbird/uikit-react-native` 3.12.10, React Native 0.81.4, and the native modules UIKit uses, each chosen so its peer range accepts React Native 0.81.4 (a plain `npm install` resolves without `--legacy-peer-deps`).
- `App.tsx` — `SendbirdUIKitContainer` at the root (init, cache, theme, session handler) and the screen switch.
- `src/sendbird/SessionBridge.tsx` — connects and disconnects through UIKit's `useConnection`, and keeps the connection handler.
- `src/auth/session.ts` — the one app-wide session store; `src/auth/login.ts` — `onLoginSucceeded` / `onLogout` for your own sign-in.
- `src/screens/LoginScreen.tsx`, `HomeScreen.tsx`, `ChannelsScreen.tsx` (UIKit list and conversation fragments).
- `src/sendbird/platformServices.ts` (native services, as in the public sample), `config.ts`, `errors.ts`; `src/auth/token.ts`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `App.tsx:22` | One `SendbirdUIKitContainer` at the app root initializes the Chat SDK once. |
| BP02 | `src/sendbird/config.ts:3` | Reads `sendbirdAppId` from `app.json`; empty is reported on the sign-in screen (`src/screens/LoginScreen.tsx:31`). |
| BP03 | `src/auth/session.ts:49` | Connects only after `onLoginSucceeded(userId)` (`src/sendbird/SessionBridge.tsx:38`). |
| BP04 | `App.tsx:30` | `setSessionHandler` in `chatOptions.onInitialized`, before any connect; the handler asks `src/auth/token.ts:3` for a token (`src/sendbird/SessionBridge.tsx:14`). |
| BP05 | `src/sendbird/SessionBridge.tsx:38` | Connects with UIKit's `useConnection().connect`, so UIKit tracks the current user. |
| BP06 | `src/screens/HomeScreen.tsx:22` | The Channels button appears only after connect returns. |
| BP07 | `src/sendbird/SessionBridge.tsx:59` | A `ConnectionHandler` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `src/sendbird/SessionBridge.tsx:59` | Added while signed in under one identifier, removed on sign-out. |
| BP09 | `src/sendbird/SessionBridge.tsx:56` | UIKit's `disconnect()` unregisters this device's push token, then disconnects. |
| BP10 | `src/sendbird/platformServices.ts:32` | UIKit's connect registers the push token through the notification service (auto registration is on by default; `src/sendbird/SessionBridge.tsx:39`). |
| BP11 | `App.tsx:16` | An MMKV store as `chatOptions.localCacheStorage`; the container turns local caching on. |
| BP12 | `App.tsx:23` | `styles.theme` on the container. |
| BP13 | `src/sendbird/errors.ts:4` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`src/sendbird/SessionBridge.tsx:49`). |
| BP15 | `App.tsx:22` | The container also follows the app state (foreground and background) for the Chat SDK. |
| BP16 | `src/auth/session.ts:1` | One store; `Screens` (`App.tsx:43`) and `SessionBridge` read it. |
| BP17 | `src/screens/LoginScreen.tsx:38` | `testID` values (see below). |

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
npm run typecheck
```

Then follow the UIKit for React Native installation guide for the native setup of each module in
`package.json` (Firebase messaging needs your Firebase project files), and run the app with your
React Native CLI.

## Stable identifiers

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `src/screens/LoginScreen.tsx:38` |
| `sb_login_button` | Sign in button | `src/screens/LoginScreen.tsx:47` |
| `sb_app_id_missing` | missing App ID message | `src/screens/LoginScreen.tsx:32` |
| `sb_connection_status` | status text | `src/screens/HomeScreen.tsx:19` |
| `sb_open_channels` | Channels button | `src/screens/HomeScreen.tsx:23` |
| `sb_logout_button` | Sign out button | `src/screens/HomeScreen.tsx:24` |
| `sb_channel_list` | container of the UIKit channel list | `src/screens/ChannelsScreen.tsx:34` |
| `sb_message_input`, `sb_send_button` | not set | UIKit for React Native 3.12.10 sets no `testID` in its components. |

## Verified

Checked on 2026-10-14:

- `npm install --ignore-scripts` and `tsc --noEmit` through the plugin's e2e build check — passes.
- Deprecated Sendbird APIs (TypeScript language service) — none.
- Not run: the plugin's runtime check does not support React Native yet, so this starter was not
  started on a device or simulator. Only the type check and the deprecation check above apply.

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
