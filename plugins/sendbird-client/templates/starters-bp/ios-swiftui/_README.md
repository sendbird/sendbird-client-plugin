<!-- status: populated -->
# iOS SwiftUI starter (best practice)

A small SwiftUI app (XcodeGen project, Swift Package Manager) with Sendbird Chat and the
SwiftUI-native Sendbird views (`SendbirdSwiftUI`) wired the recommended way: sign-in with a user ID,
connect, the channel list and conversation, and sign-out. Start a new app from this folder, then
replace the user ID field with your own sign-in. The practices it follows are listed in
`../BEST_PRACTICES.md`.

## What is included

- `project.yml` — XcodeGen spec: iOS 15, packages `sendbird-chat-sdk-ios` 4.39.11 and `sendbird-swiftui-ios` 1.2.2 (exact versions). The docs state SendbirdSwiftUI supports iPhone only.
- `Config/Sendbird.xcconfig` — the `SENDBIRD_APP_ID` build setting; your value goes in `Config/Sendbird.local.xcconfig` (not committed).
- `Sources/SendbirdSession.swift` — the one app-wide session (`ObservableObject`): init, connect, connection and session delegates, push token, sign-out.
- `Sources/LoginService.swift` — `onLoginSucceeded(userId:)` / `onLogout()` for your own sign-in.
- `Sources/StarterApp.swift` (`@main`, `RootView`), `Sources/AppDelegate.swift` (launch and push token through `@UIApplicationDelegateAdaptor`).
- `Sources/LoginView.swift`, `Sources/HomeView.swift` (home screen and `ChannelListScreen` with `GroupChannelListView`).
- `Sources/AppConfig.swift`, `Sources/TokenProvider.swift`, `Sources/SendbirdErrors.swift`, `Sources/StarterTheme.swift`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `Sources/AppDelegate.swift:8` | `SendbirdUI.initialize` runs once at launch (`Sources/SendbirdSession.swift:45`). |
| BP02 | `Sources/AppConfig.swift:5` | Reads `SendbirdAppId` from Info.plist, filled from the build setting (`Config/Sendbird.xcconfig:1`, `project.yml:8`); empty is reported on the sign-in screen (`Sources/LoginView.swift:16`). |
| BP03 | `Sources/SendbirdSession.swift:76` | Connects only after `onLoginSucceeded(userId:)`; a sign-in that arrives before init finishes waits for it. |
| BP04 | `Sources/SendbirdSession.swift:91` | `setSessionDelegate` before connect; the delegate asks `TokenProvider` (`Sources/TokenProvider.swift:5`) for a new token (`Sources/SendbirdSession.swift:180`). |
| BP05 | `Sources/SendbirdSession.swift:97` | Sets `SBUGlobals.currentUser` and connects with `SendbirdUI.connect`. |
| BP06 | `Sources/HomeView.swift:10` | The Channels link appears only after connect returns (`Sources/SendbirdSession.swift:118`). |
| BP07 | `Sources/SendbirdSession.swift:195` | A `ConnectionDelegate` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `Sources/SendbirdSession.swift:137` | Delegates are added before connect under one identifier and removed on sign-out. |
| BP09 | `Sources/SendbirdSession.swift:127` | `SendbirdUI.unregisterPushToken`, then `SendbirdUI.disconnect` in its completion. |
| BP10 | `Sources/AppDelegate.swift:10` | One marked place to turn on push; the token is registered for the signed-in user after connect (`Sources/SendbirdSession.swift:162`). |
| BP11 | `Sources/SendbirdSession.swift:52` | `isLocalCachingEnabled = true`. |
| BP12 | `Sources/StarterTheme.swift:5` | `SBUTheme.set(colorScheme:)` once, before SendbirdSwiftUI initializes. |
| BP13 | `Sources/SendbirdErrors.swift:6` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`Sources/SendbirdSession.swift:110`). |
| BP14 | `Sources/HomeView.swift:44` | The host navigation bar is hidden on the view that hosts the Sendbird screen. |
| BP16 | `Sources/SendbirdSession.swift:13` | `SendbirdSession.shared`; `RootView` observes it (`Sources/StarterApp.swift:13`) and `LoginService` forwards to it (`Sources/LoginService.swift:4`). No view owns its own copy, so a sign-in from any path connects. |
| BP17 | `Sources/LoginView.swift:24` | Accessibility identifiers (see below). |

Not applicable here: BP15 (React Native).

## Set the App ID

1. Create `Config/Sendbird.local.xcconfig` (it is in `.gitignore`) with one line: `SENDBIRD_APP_ID = <your App ID>`
2. Run `xcodegen generate` and build. The value is compiled into Info.plist, so the app reads the
   same App ID however it is launched.

Command-line builds can pass it instead: `xcodebuild ... SENDBIRD_APP_ID=<your App ID>`. The App ID
is not a secret; session and access tokens are, and never go into these files.

## Run

```bash
brew install xcodegen          # once
xcodegen generate
open StarterSwiftUI.xcodeproj  # or:
xcodebuild -project StarterSwiftUI.xcodeproj -scheme StarterSwiftUI -destination 'generic/platform=iOS Simulator' build
```

## Stable identifiers

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `Sources/LoginView.swift:24` |
| `sb_login_button` | Sign in button | `Sources/LoginView.swift:28` |
| `sb_app_id_missing` | missing App ID message | `Sources/LoginView.swift:19` |
| `sb_connection_status` | status text | `Sources/HomeView.swift:19` |
| `sb_open_channels` | Channels link | `Sources/HomeView.swift:22` |
| `sb_logout_button` | Sign out button | `Sources/HomeView.swift:25` |
| `sb_channel_list` | container of `GroupChannelListView` | `Sources/HomeView.swift:43`. Set on the container; the runtime check did not look it up. |
| `sb_message_input`, `sb_send_button` | not set | SendbirdSwiftUI 1.2.2 hands no input view to app code. A test can use the text view nearest the bottom of the conversation screen and the button to its right. |

## Verified

Checked on 2026-10-14 with Xcode 27 and the iOS 27 simulator:

- `xcodegen generate` + `xcodebuild` for the simulator and for a generic iOS device — BUILD SUCCEEDED, no warnings in app code.
- Deprecated SDK APIs (the plugin's e2e build-log check) — none.
- Runtime, against a test application, with the App ID passed as a build setting: the app signs in
  through `LoginService().onLoginSucceeded(userId:)` called on a new `LoginService` right after
  launch, connects (the server reports the user online), the Channels link opens the list (one
  navigation bar), a channel opened by a second user appears and opens, the second user's message
  shows, a reply typed in the input reaches the server, and a later message from the second user
  appears without reopening the screen. The app stays in the foreground throughout.
- Sign-out, on a copy that calls `LoginService().onLogout()` 15 seconds after signing in: the
  server reports the user online, then offline.
- Not exercised: push (no APNs setup in the test).

## Next steps

- Your sign-in: call `LoginService().onLoginSucceeded(userId:)` after it succeeds.
- Tokens: return a session token from your server in `Sources/TokenProvider.swift`
  (`knowledge/curated/ios/products/auth.md`).
- Push: add the capability and APNs key, then follow `knowledge/curated/ios/cross-cutting/push.md`.
- Customizing the Sendbird views, theme, and strings: `knowledge/curated/ios/hosts/swiftui.md`.

(source: knowledge/curated/ios/hosts/swiftui.md)
(source: knowledge/curated/ios/products/uikit.md)
(source: knowledge/curated/ios/cross-cutting/push.md)
