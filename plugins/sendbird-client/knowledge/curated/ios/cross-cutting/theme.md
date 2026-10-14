<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- verified-at: 2026-10-12 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — theme (UIKit)

> Verified against the public UIKit README, the public SendbirdUIKit `.swiftinterface`, and pinned/latest iOS template xcodebuild on 2026-09-22. The runtime switch, fonts and colors, and strings sections were read from the public source at tag `3.36.1` and build with `tools/curated/compile-snippets-ios.sh` (verified 2026-10-11). The message input colors and date format sections were read from the same tag and build the same way (verified 2026-10-12). Used by `/sendbird-client:ui-customize`. Do not invent API.

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

## Switch light/dark while screens are open
`SBUTheme.set(colorScheme:)` replaces every component theme with the SDK defaults for that scheme. Any color you assigned to a component theme is dropped. On every appearance change, set the scheme first, re-apply your overrides, then call `updateStyles()` on the Sendbird screen that is showing. UIKit does not do this for you.

```swift
import UIKit
import SendbirdUIKit

@MainActor
func applySendbirdAppearance(isDark: Bool, visibleScreen: SBUBaseViewController?) {
    SBUTheme.set(colorScheme: isDark ? .dark : .light)             // 1. resets every component theme
    SBUTheme.channelTheme.leftBarButtonTintColor = .systemIndigo   // 2. re-apply your overrides
    visibleScreen?.updateStyles()                                  // 3. restyle what is on screen
}
```
Call it from your own appearance toggle, or from wherever your app observes the system appearance. The SDK's own doc comment on `set(colorScheme:)` describes these three steps. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L82-L117; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUBaseViewController.swift#L116-L117 (`updateStyles()`))

## Fonts and colors
`SBUFontSet` (`h1`…`h3`, `body1`…`body4`, `button1`…`button4`, `caption1`…`caption4`, `subtitle1`…`subtitle3`) and `SBUColorSet` (for example `primaryMain`) are static values. Component themes copy them when the theme objects are created. The first `SBUTheme` is created the first time it is used, and `set(colorScheme:)` creates new ones. So change the sets first, then call `set(colorScheme:)`. If you change a set after the themes exist and do not rebuild them, the screens keep the old font or color.

```swift
import UIKit
import SendbirdUIKit

SBUFontSet.body1 = UIFont(name: "AvenirNext-Regular", size: 16) ?? SBUFontSet.body1
SBUFontSet.h1 = UIFont(name: "AvenirNext-Bold", size: 18) ?? SBUFontSet.h1
SBUColorSet.primaryMain = .systemIndigo
SBUTheme.set(colorScheme: .light)   // rebuilds the themes so they pick up the new values
```
`SBUColorSet.primary300` and the other numbered primary colors are deprecated aliases of `primaryExtraLight`, `primaryLight`, `primaryMain`, and `primaryDark`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUFontSet.swift#L15-L231; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUColorSet.swift#L14-L18 (deprecated `primary300` at lines 173–177); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L583-L596 (a theme copies `SBUFontSet`/`SBUColorSet` when created; `shared` at line 333); source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/theme-resources)

## Strings and localization
Every string UIKit shows is a static property of `SBUStringSet`. The public source ships no `.strings` files, and the defaults are English literals in `SBUStringSet.swift`. To localize, or just to reword, assign your own values once at launch, before the first screen is created. A few entries are closures because they depend on a count or on users.

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

SBUStringSet.ChannelList_Header_Title = NSLocalizedString("chat.channels.title", comment: "")
SBUStringSet.MessageInput_Text_Placeholder = NSLocalizedString("chat.input.placeholder", comment: "")
SBUStringSet.Channel_Typing = { (members: [User]) in
    String(format: NSLocalizedString("chat.typing.count", comment: ""), members.count)
}
```
The docs page lists every key. Where the docs text and the source differ, the source is what ships; for example, the default `MessageInput_Text_Placeholder` in 3.36.1 is "Enter message". SendbirdSwiftUI exposes the same `SBUStringSet` (see knowledge/curated/ios/hosts/swiftui.md). (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUStringSet.swift#L17-L201 (`ChannelList_Header_Title` at line 74, `Channel_Typing` at line 87, `MessageInput_Text_Placeholder` at line 201); source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/string-resources)

## Message input colors
`SBUMessageInputView` reads its colors from `SBUTheme.messageInputTheme` in `setupStyles()`. Since 3.34.0 the background, text field background, and text field border colors are Liquid Glass-adaptive: `backgroundColorAdaptive`, `textFieldBackgroundColorAdaptive`, and `textFieldBorderColorAdaptive` hold one value for the classic look and one for Liquid Glass. The old names (`backgroundColor`, `textFieldBackgroundColor`, `textFieldBorderColor`) are deprecated. An adaptive property is read-only; change it through its `$` wrapper with `updateValues(base:liquidGlass:)`, where a `nil` argument keeps that value. `buttonTintColor` is still a plain property.

```swift
import UIKit
import SendbirdUIKit

SBUTheme.set(colorScheme: .light)   // first: it replaces the theme objects
let inputTheme = SBUTheme.messageInputTheme
inputTheme.$backgroundColorAdaptive.updateValues(base: .secondarySystemBackground)
inputTheme.$textFieldBackgroundColorAdaptive.updateValues(base: .systemBackground)
inputTheme.$textFieldBorderColorAdaptive.updateValues(base: .systemBlue, liquidGlass: .systemBlue)
inputTheme.buttonTintColor = .systemBlue
```
For one screen type only, override `setupStyles()` in an input view subclass instead (knowledge/curated/ios/products/uikit.md, "Restyle the input bar on open channels only"). (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1397-L1456 (deprecated setters, adaptive properties at lines 1452–1456, `buttonTintColor` at line 1443); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Util/SBUPropertyWrapper.swift#L176-L235 (`SBUAdaptive`: read-only `wrappedValue`, `updateValues(base:liquidGlass:)`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L902-L953; community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/125)

## Date and time formats
`SBUDateFormatSet` holds the format strings UIKit uses for dates, for example `SBUDateFormatSet.Message.sentTimeFormat` (the time under a message in group channels and threads, default `"hh:mm"`) and `SBUDateFormatSet.Message.sentTimeFormatInOpenChannel`. UIKit passes them to `DateFormatter.setLocalizedDateFormatFromTemplate(_:)`, so each string is a template: the device locale decides the order and separators.

```swift
import SendbirdUIKit

// Once at launch, before the first channel screen:
SBUDateFormatSet.Message.sentTimeFormat = "HH:mm"
SBUDateFormatSet.Message.sentTimeFormatInOpenChannel = "HH:mm"
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUDateFormatSet.swift#L50-L66; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/Date+SBUIKit.swift#L30-L38 (`sbu_toString(dateFormat:localizedFormat:)`, template by default); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUMessageStateView.swift#L170 (group channel time); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/OpenChannel/SBUOpenChannelContentBaseMessageCell.swift#L222 (open channel time); source: https://developer.apple.com/documentation/foundation/dateformatter/setlocalizeddateformatfromtemplate(_:); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/74)

## Pitfalls
- Set theme/color/font overrides before presenting the UIKit view controller.
- Apply your changes when the user toggles theme (it is not automatic).
- `SBUTheme.set(theme:)` and `SBUTheme.set(colorScheme:)` drop per-component colors you set earlier. Re-apply them after each call.
- Alert text unreadable in dark mode with a theme you built yourself: UIKit alerts (`SBUAlertView`) take their colors from `SBUTheme.componentTheme` (`alertTitleColor`, `alertDetailColor`). A `SBUComponentTheme` created with its initializer defaults to the light colors (`onLightTextHighEmphasis`, `onLightTextMidEmphasis`), while `SBUComponentTheme.dark` uses the dark ones. For dark mode, start from `SBUComponentTheme.dark` or set those two colors yourself. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/AlertView/SBUAlertView.swift#L289-L307 (`theme` is `SBUTheme.componentTheme`, line 28); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L3624-L3640 (initializer defaults), lines 3340–3362 (`dark`))

## Related
- UIKit: knowledge/curated/ios/products/uikit.md
- AI Agent theme: knowledge/curated/ios/cross-cutting/ai-agent-theme.md
