<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — theme (UIKit)

> Verified against the public UIKit README, the public SendbirdUIKit `.swiftinterface`, and pinned/latest iOS template xcodebuild on 2026-09-22. Used by `/sendbird-client:ui-customize`. Do not invent API.

## Overview
Sendbird UIKit for iOS themes through three singletons: `SBUTheme` (themes), `SBUColorSet` (colors), `SBUFontSet` (fonts). Switch light/dark globally, or override per-component theme objects.

## Light / dark
```swift
import SendbirdUIKit

SBUTheme.set(colorScheme: .light)   // or .dark
```
(source: sendbird-uikit-ios README §components — `SBUTheme`/`SBUColorSet`/`SBUFontSet`; `SBUTheme.set(colorScheme:)` in the SendbirdUIKit 3.36.2 public `.swiftinterface` (`ios-arm64`), class `SBUTheme`)

## Per-component overrides
```swift
SBUTheme.channelTheme.leftBarButtonTintColor = .black
```
Component theme objects (e.g. `SBUTheme.channelTheme`, channel-list theme, etc.) expose tint/color/font properties; set them before presenting the screen. (source: SendbirdUIKit 3.36.2 public `.swiftinterface` (`ios-arm64`) — `SBUTheme.channelTheme: SBUChannelTheme`, `SBUChannelTheme.leftBarButtonTintColor`)

## Pitfalls
- Set theme/color/font overrides before presenting the UIKit view controller.
- Apply your changes when the user toggles theme (it is not automatic).

## Related
- UIKit: knowledge/curated/ios/products/uikit.md
- AI Agent theme: knowledge/curated/ios/cross-cutting/ai-agent-theme.md
