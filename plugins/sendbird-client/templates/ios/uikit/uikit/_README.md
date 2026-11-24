<!-- status: populated -->
# templates/ios/uikit/uikit

Sendbird UIKit on iOS. From the public `sendbird-uikit-ios` README quickstart
(verified 2026-06-09). **Build-verified** against `SendbirdUIKit` (xcodebuild BUILD SUCCEEDED).

## Files
- `SetupUIKit.swift` — `initialize()` / `setCurrentUser(...)` / `presentChannelList(from:)`.
- `BrandChatTheme.swift` — theme: font and color sets (whole primary ramp; dark mode reads `primaryLight`), `SBUTheme.set(colorScheme:)`, bubble colors on `messageCellTheme`, and a navigation controller that follows the system appearance and restyles open screens, including the input bar.

## How to splice
1. SPM package `https://github.com/sendbird/sendbird-uikit-ios-spm`, product `SendbirdUIKit` (prefer SPM, no CocoaPods).
2. Call `SendbirdUIKitBootstrap.initialize()` once at launch.
3. Call `setCurrentUser(userId:)` before presenting any screen, then `presentChannelList(from:)`.
4. App ID from the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting (see `knowledge/curated/ios/setup.md` "App ID") — never hard-code; access token is a secret.

## Variations (see knowledge/curated/ios/products/uikit.md, all cited)
- Open a specific channel: `SBUGroupChannelViewController(channelURL:)`.
- Feature toggles: `SendbirdUI.config.groupChannel.*` before presenting.

## Theme (dark mode, brand colors, font, bubble colors)
Use `BrandChatTheme.swift` when the request is to restyle the UIKit screens. Keep only the parts the request asks for and take the values from the app. Call `BrandChatTheme.configureAtLaunch(style:)` after `SendbirdUI.initialize` and before the first screen, and use `BrandChatNavigationController` as the container of the Sendbird screens. Details and sources: knowledge/curated/ios/cross-cutting/theme.md.
