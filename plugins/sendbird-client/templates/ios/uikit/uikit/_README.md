<!-- status: populated -->
# templates/ios/uikit/uikit

Sendbird UIKit on iOS. From the public `sendbird-uikit-ios` README quickstart
(verified 2026-06-09). **Build-verified** against `SendbirdUIKit` (xcodebuild BUILD SUCCEEDED).

## Files
- `SetupUIKit.swift` — `initialize()` / `setCurrentUser(...)` / `presentChannelList(from:)`.

## How to splice
1. SPM package `https://github.com/sendbird/sendbird-uikit-ios-spm`, product `SendbirdUIKit` (prefer SPM, no CocoaPods).
2. Call `SendbirdUIKitBootstrap.initialize()` once at launch.
3. Call `setCurrentUser(userId:)` before presenting any screen, then `presentChannelList(from:)`.
4. App ID from env — never hard-code; access token is a secret.

## Variations (see knowledge/curated/ios/products/uikit.md, all cited)
- Open a specific channel: `SBUGroupChannelViewController(channelURL:)`.
- Feature toggles: `SendbirdUI.config.groupChannel.*` before presenting.
