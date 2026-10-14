<!-- status: populated -->
# iOS UIKit starter (best practice)

A small UIKit app (XcodeGen project, Swift Package Manager) with Sendbird Chat and UIKit wired the
recommended way: sign-in with a user ID, connect, the UIKit channel list and conversation, and
sign-out. Start a new app from this folder, then replace the user ID field with your own sign-in.
The practices it follows are listed in `../BEST_PRACTICES.md`.

## What is included

- `project.yml` — XcodeGen spec: iOS 15, packages `sendbird-chat-sdk-ios` 4.39.11 and `sendbird-uikit-ios-spm` 3.36.1 (exact versions).
- `Config/Sendbird.xcconfig` — the `SENDBIRD_APP_ID` build setting; your value goes in `Config/Sendbird.local.xcconfig` (not committed).
- `Sources/SendbirdSession.swift` — the one app-wide session: init, connect, connection and session delegates, push token, sign-out.
- `Sources/LoginService.swift` — `onLoginSucceeded(userId:)` / `onLogout()` for your own sign-in.
- `Sources/LoginViewController.swift`, `Sources/HomeViewController.swift` — sign-in and home screens; `Sources/SceneDelegate.swift` switches between them.
- `Sources/ChannelScreens.swift` — the UIKit channel list and conversation subclasses that carry the stable identifiers.
- `Sources/AppConfig.swift`, `Sources/TokenProvider.swift`, `Sources/SendbirdErrors.swift`, `Sources/StarterTheme.swift`.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `Sources/AppDelegate.swift:8` | `SendbirdUI.initialize` runs once at launch (`Sources/SendbirdSession.swift:48`). |
| BP02 | `Sources/AppConfig.swift:5` | Reads `SendbirdAppId` from Info.plist, filled from the build setting (`Config/Sendbird.xcconfig:1`, `project.yml:7`); empty is reported on the sign-in screen (`Sources/LoginViewController.swift:33`). |
| BP03 | `Sources/SendbirdSession.swift:82` | Connects only after `onLoginSucceeded(userId:)`; a sign-in that arrives before init finishes waits for it. |
| BP04 | `Sources/SendbirdSession.swift:97` | `setSessionDelegate` before connect; the delegate asks `TokenProvider` (`Sources/TokenProvider.swift:5`) for a new token (`Sources/SendbirdSession.swift:186`). |
| BP05 | `Sources/SendbirdSession.swift:103` | Sets `SBUGlobals.currentUser` and connects with `SendbirdUI.connect`. |
| BP06 | `Sources/HomeViewController.swift:60` | The Channels button appears only after connect returns (`Sources/SendbirdSession.swift:124`). |
| BP07 | `Sources/SendbirdSession.swift:201` | A `ConnectionDelegate` drives the status line (Connected, Reconnecting…, Offline). |
| BP08 | `Sources/SendbirdSession.swift:143` | Delegates are added before connect under one identifier and removed on sign-out. |
| BP09 | `Sources/SendbirdSession.swift:133` | `SendbirdUI.unregisterPushToken`, then `SendbirdUI.disconnect` in its completion. |
| BP10 | `Sources/AppDelegate.swift:10` | One marked place to turn on push; the token is registered for the signed-in user after connect (`Sources/SendbirdSession.swift:168`). |
| BP11 | `Sources/SendbirdSession.swift:58` | `isLocalCachingEnabled = true` (UIKit 3.33.1 and later keep it on in any case). |
| BP12 | `Sources/StarterTheme.swift:5` | `SBUTheme.set(colorScheme:)` once, before the first UIKit screen. |
| BP13 | `Sources/SendbirdErrors.swift:6` | Maps the verified error codes to a message; a failed connect shows it on the sign-in screen (`Sources/SendbirdSession.swift:116`). |
| BP16 | `Sources/SendbirdSession.swift:13` | `SendbirdSession.shared`; `LoginService` (`Sources/LoginService.swift:4`) and the scene (`Sources/SceneDelegate.swift:4`) all use it. |
| BP17 | `Sources/ChannelScreens.swift:28` | Accessibility identifiers, including the UIKit input and send button (see below). |

Not applicable here: BP14 (SwiftUI), BP15 (React Native).

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
open StarterUIKit.xcodeproj    # or:
xcodebuild -project StarterUIKit.xcodeproj -scheme StarterUIKit -destination 'generic/platform=iOS Simulator' build
```

## Stable identifiers

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID field | `Sources/LoginViewController.swift:22` |
| `sb_login_button` | Sign in button | `Sources/LoginViewController.swift:27` |
| `sb_app_id_missing` | missing App ID message | `Sources/LoginViewController.swift:37` |
| `sb_connection_status` | status label | `Sources/HomeViewController.swift:17` |
| `sb_open_channels` | Channels button | `Sources/HomeViewController.swift:20` |
| `sb_logout_button` | Sign out button | `Sources/HomeViewController.swift:24` |
| `sb_channel_list` | the UIKit channel list view | `Sources/ChannelScreens.swift:12` |
| `sb_message_input` | the UIKit message text view | `Sources/ChannelScreens.swift:31`, set through the public `inputComponent.messageInputView` |
| `sb_send_button` | the UIKit send button | `Sources/ChannelScreens.swift:32` |

## Verified

Checked on 2026-10-14 with Xcode 27 and the iOS 27 simulator:

- `xcodegen generate` + `xcodebuild` for the simulator and for a generic iOS device — BUILD SUCCEEDED, no warnings in app code.
- Deprecated SDK APIs (the plugin's e2e build-log check) — none.
- Runtime, against a test application, with the App ID passed as a build setting: the app signs in
  through `LoginService().onLoginSucceeded(userId:)` called right after launch, connects (the
  server reports the user online), the Channels button opens the list, a channel opened by a second
  user appears and opens, the second user's message shows, a reply typed in the UIKit input and sent
  with the `sb_send_button` button reaches the server, and a later message from the second user
  appears without reopening the screen. The app stays in the foreground throughout.
- Sign-out, on a copy that calls `LoginService().onLogout()` 15 seconds after signing in: the
  server reports the user online, then offline.
- Not exercised: push (no APNs setup in the test).

## Next steps

- Your sign-in: call `LoginService().onLoginSucceeded(userId:)` after it succeeds.
- Tokens: return a session token from your server in `Sources/TokenProvider.swift`
  (`knowledge/curated/ios/products/auth.md`).
- Push: add the capability and APNs key, then follow `knowledge/curated/ios/cross-cutting/push.md`.
- Theme, dark mode, strings: `knowledge/curated/ios/cross-cutting/theme.md`.
- Customizing UIKit screens: `knowledge/curated/ios/products/uikit.md`.

(source: knowledge/curated/ios/products/uikit.md)
(source: knowledge/curated/ios/cross-cutting/push.md)
(source: knowledge/curated/ios/cross-cutting/theme.md)
