<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- status: populated -->
# ios uikit

> Verified against the public mirror `sendbird/sendbird-uikit-ios` (README quickstart + QuickStart sample, verified 2026-06-09). init + currentUser + channel list build-verified locally (xcodebuild). Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-uikit-ios

## Overview
Sendbird UIKit gives prebuilt chat screens (channel list, conversation, settings) on top of Chat. Initialize UIKit, set the current user, then present the provided view controllers.

## Install (SPM — prefer over CocoaPods)
- SPM package `https://github.com/sendbird/sendbird-uikit-ios-spm`, products `SendbirdUIKit` (+ `SendbirdUIMessageTemplate`). `import SendbirdUIKit`.

## Initialize (once, at launch)
```swift
import SendbirdUIKit

SendbirdUI.initialize(applicationId: APP_ID) {
    // initialization started
} migrationHandler: {
    // DB migration progress
} completionHandler: { error in
    // ready when error == nil
}
```
(source: sendbird-uikit-ios README §getting-started; build-verified)

## Set the current user (required)
```swift
SBUGlobals.currentUser = SBUUser(userId: USER_ID)
// or: SBUUser(userId: USER_ID, nickname: NICKNAME, profileURL: PROFILE_URL)
```
Without `currentUser` set, UIKit usage is restricted. For authenticated apps set `SBUGlobals.accessToken`. (source: sendbird-uikit-ios README; build-verified)

## Present prebuilt screens
```swift
let groupChannelListVC = SBUGroupChannelListViewController()
let naviVC = UINavigationController(rootViewController: groupChannelListVC)
present(naviVC, animated: true)            // or navigationController?.pushViewController

let channelVC = SBUGroupChannelViewController(channelURL: CHANNEL_URL)
```
(source: sendbird-uikit-ios README §"Channel list" + §"Channel")

## Config (optional, before presenting)
`SendbirdUI.config.groupChannel.channel.*` and `.channelList.*` toggle features (reply type, typing indicator, reactions, mention, voice/file messages, etc.). See the QuickStart sample. (source: sendbird-uikit-ios QuickStart AppDelegate)

## Customize channel selection
Subclass and override the module delegate method to customize what happens when a channel row is tapped (e.g. push a custom detail screen instead of the default conversation screen):
```swift
final class MyChannelListViewController: SBUGroupChannelListViewController {
    override func baseChannelListModule(_ listComponent: SBUBaseChannelListModule.List, didSelectRowAt indexPath: IndexPath) {
        // Call super to keep the built-in navigation, or handle it yourself to replace it —
        // verify the exact default behavior against your installed version before relying on it.
    }
}
```
`SBUGroupChannelListViewController` is declared `open`, and `baseChannelListModule(_:didSelectRowAt:)` is an `open` override point on it (inherited from `SBUBaseChannelListViewController`); both are confirmed in the shipped interface. The method's default implementation isn't visible in a `.swiftinterface` (signatures only) — do not assume its exact behavior without checking the sample or your installed version. (source: `SendbirdUIKit.swiftinterface` (3.36.0) line 6132 `SBUGroupChannelListViewController`, line 6220 `baseChannelListModule(_:didSelectRowAt:)`)

## Pitfalls
- Initialize once at launch; set `currentUser` before presenting any UIKit screen.
- App ID from config/env; access token is a secret — never hard-code.
- UIKit is UIViewController-based — for SwiftUI, wrap in `UIViewControllerRepresentable`.

## Related
- Repo + quickstart: https://github.com/sendbird/sendbird-uikit-ios
- Theming: knowledge/curated/ios/cross-cutting/theme.md
- Underlying Chat: knowledge/curated/ios/products/chat.md
