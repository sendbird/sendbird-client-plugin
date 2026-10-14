# Best-practice starters — checklist

Each starter under `templates/starters-bp/<host>/` is a small app with sign-in, connect, a channel
list, a channel screen (Sendbird UIKit), and sign-out. This file lists the practices the starters
follow and where each one comes from. Every item is taken from the plugin's curated knowledge
(`knowledge/curated/<platform>/...`, section in quotes), which cites the public docs or the shipped
SDK. Where a starter shows a practice is listed in its `_README.md` (file:line).

Items marked **design rule** describe how the starter app is put together; they make no claim
about SDK behavior.

## Checklist

Paths in the Source column are relative to `knowledge/curated/`.

| ID | Practice | Source |
|---|---|---|
| BP01 | Initialize the SDK once, at the app entry, and reuse the instance. Never initialize per screen or per render. | `js/setup.md` "Init"; `js/products/chat.md` "Initialize (once) + modules"; `js/hosts/react.md` "Integration notes"; `ios/products/uikit.md` "Initialize (once, at launch)"; `ios/cross-cutting/performance.md` "Anti-patterns to flag"; `android/setup.md` "Init"; `android/hosts/compose.md` "UIKit for Jetpack Compose — init, then push" |
| BP02 | Read the App ID from build configuration, never from a literal in code and never from a process environment variable alone. React: `VITE_SENDBIRD_APP_ID` in `.env.local` (inlined at build time). React Native: `sendbirdAppId` in `app.json`, read by a config module (no env loader added). iOS: an `.xcconfig` build setting written into `Info.plist`. Android: a Gradle property, environment variable, or `local.properties` value passed on with `buildConfigField`. A missing value is reported at start-up instead of failing the build. | `js/setup.md` "App ID"; `ios/setup.md` "Pitfalls"; `ios/products/chat.md` "Pitfalls"; `android/setup.md` "App ID in Gradle" |
| BP03 | Connect only after the app's own sign-in succeeds, with that user's ID. Secured apps pass a session or access token issued by their server; the token is never hard-coded, logged, or committed. | `js/products/auth.md` "Connect (session token)", "Pitfalls"; `ios/products/auth.md` "Connect (session token)", "Token rules"; `android/products/auth.md` "Connect (session token)" |
| BP04 | Set the session handler (token refresh hook) before connecting. The starters leave a single hook that returns no token; plug your server call in there. | `js/products/auth.md` "Token refresh — SessionHandler (set before connect)"; `ios/products/auth.md` "Token refresh — SessionDelegate"; `android/products/auth.md` "Session token expiry" |
| BP05 | With UIKit, tell UIKit who the user is and connect through UIKit's own connect call, not the Chat SDK's, so UIKit knows which messages are the user's own. | `ios/products/uikit.md` "Set the current user (required)"; `ios/cross-cutting/troubleshooting.md` "UIKit shows every message on the left, or UIKit features such as reactions are missing"; `android/products/uikit.md` "Initialize (Application class)", "Pitfalls"; `android/hosts/compose.md` "UIKit for Jetpack Compose — init, then push"; `js/products/uikit.md` "React" |
| BP06 | Call server APIs (open the channel list, unread counts) only after connect completes; until then the UI offers no chat action. | `js/products/chat.md`, `ios/products/chat.md`, `android/products/chat.md` "Call APIs only after connect completes" |
| BP07 | Observe the connection with a connection handler (reconnect started, succeeded, failed) instead of polling. The SDK reconnects by itself; the handler only drives a status line. | `js/products/chat.md`, `ios/products/chat.md`, `android/products/chat.md` "Connection state and reconnection"; `js/cross-cutting/pitfalls.md` "Connection lifecycle"; `js/products/uikit.md` "After a reconnect" |
| BP08 | Register handlers before connect and remove every handler you add when the user signs out or the screen goes away (one identifier per handler). | `js/products/chat.md` "Pitfalls"; `js/cross-cutting/performance.md` "Anti-patterns to flag"; `ios/products/chat.md` "Pitfalls"; `ios/cross-cutting/performance.md` "Anti-patterns to flag"; `android/products/chat.md` "Pitfalls"; `android/cross-cutting/performance.md` "Anti-patterns to flag" |
| BP09 | Sign-out order: unregister this device's push token first, then disconnect in its completion. Disconnecting alone does not stop push. | `js/cross-cutting/push.md` "Logout: unregister this device before disconnecting"; `ios/cross-cutting/push.md` "One token, one device, one signed-in user"; `android/cross-cutting/push.md` "Logout: unregister this device before disconnecting" |
| BP10 | Register the push token after connect, for the signed-in user only. The starters keep one marked registration point and do not request notification permission or add push credentials. | `js/cross-cutting/push.md` "Pitfalls"; `ios/cross-cutting/push.md` "Register / unregister the APNs token", "Token registered before connect (pending)"; `android/cross-cutting/push.md` "Handler-based vs manual token registration" |
| BP11 | Keep local caching on so the channel list and chat screen work from cached data. | `ios/products/chat.md`, `android/products/chat.md`, `js/products/chat.md` "Local caching and offline messages"; `ios/cross-cutting/performance.md` and `android/cross-cutting/performance.md` "Anti-patterns to flag" (local caching off); `js/hosts/react.md` "Multiple tabs or windows" (React UIKit turns it on by default); `js/hosts/react-native.md` "UIKit container: local cache storage" |
| BP12 | Set the UIKit theme in one place, before the first UIKit screen is created. | `ios/cross-cutting/theme.md` "Light / dark"; `ios/hosts/swiftui.md` "Theme, dark mode, strings"; `android/cross-cutting/theme.md` "Light / dark (View host)", "Jetpack Compose host"; `js/cross-cutting/theme.md` "Light / dark", "Brand colors (`colorSet`) and strings (`stringSet`)" |
| BP13 | Show the error code and pick the next step from the verified error table: token errors (400300, 400301, 400302, 400310) go back to sign-in, connection required (800101) waits for connect, a network error (800120) waits for the reconnection. | `js/cross-cutting/errors.md` "Handling tips", "Connection failures"; `ios/cross-cutting/errors.md` "Handling tips", "Diagnosing connection failures"; `android/cross-cutting/errors.md` "Handling tips"; `js/products/chat.md`, `ios/products/chat.md`, `android/products/chat.md` "Call APIs only after connect completes" |
| BP14 | SwiftUI: hide the host navigation bar on the view that hosts a Sendbird screen, because the Sendbird view brings its own. | `ios/cross-cutting/troubleshooting.md` "Sendbird SwiftUI screens show two navigation bars" |
| BP15 | React Native: let the UIKit container own init and app-state handling, and give it an MMKV instance for the local cache. | `js/hosts/react-native.md` "App lifecycle (Chat SDK without UIKit)", "UIKit container: local cache storage"; `js/products/uikit.md` "React Native" |
| BP16 | **Design rule.** Keep the session in one app-wide object. Every path that signs in (the sign-in screen, a deep link, a test) calls that object, and every screen reads its state from it, so no screen holds a private copy that never connects. | — |
| BP17 | **Design rule.** Give the controls a test or a support engineer needs a stable identifier (list below). | — |

## Stable identifiers

The starters use these names. They are snake_case so the same name works as an Android resource
id, an iOS accessibility identifier, a Compose test tag, and a web `data-testid`.

| Identifier | Control |
|---|---|
| `sb_login_user_id` | user ID field on the sign-in screen |
| `sb_login_button` | sign-in button |
| `sb_app_id_missing` | message shown when no App ID was configured |
| `sb_connection_status` | connection status line |
| `sb_open_channels` | button that opens the channel list |
| `sb_channel_list` | channel list container |
| `sb_message_input` | message input on the channel screen |
| `sb_send_button` | send button on the channel screen |
| `sb_logout_button` | sign-out button |

Where a UIKit owns the message input or send button and offers no supported way to label it, the
host's `_README.md` says so and names what a test can use instead.

## Versions

Pinned to the versions the curated docs are stamped against:

| Host | Packages |
|---|---|
| react | `@sendbird/chat` 4.22.13, `@sendbird/uikit-react` 3.19.1 |
| react-native | `@sendbird/chat` 4.22.13, `@sendbird/uikit-react-native` 3.12.10 |
| ios-uikit | `sendbird-chat-sdk-ios` 4.39.11, `sendbird-uikit-ios-spm` 3.36.1 |
| ios-swiftui | `sendbird-chat-sdk-ios` 4.39.11, `sendbird-swiftui-ios` 1.2.2 |
| android-view | `sendbird-chat` 4.36.5, `uikit` 3.26.3 |
| android-compose | `sendbird-chat` 4.36.5, `uikit-compose` 1.3.6 |

## Not included

- Push credentials (APNs key, `google-services.json`) and the notification permission prompt. The
  registration point is in place; see each `_README.md`.
- A token server. The token hook returns no token, which works only with an application that
  allows connecting with a user ID alone. Production apps issue tokens from their server.

## Sources

(source: knowledge/curated/js/hosts/react-native.md)
(source: knowledge/curated/js/products/uikit.md)
(source: knowledge/curated/js/products/chat.md)
(source: knowledge/curated/ios/products/uikit.md)
(source: knowledge/curated/android/products/uikit.md)
