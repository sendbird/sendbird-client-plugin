<!-- last-verified-against: sendbird-uikit-ios 3.36.1 -->
<!-- verified-at: 2026-11-23 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — theme (UIKit)

> Verified against the public UIKit README, the public SendbirdUIKit `.swiftinterface`, and pinned/latest iOS template xcodebuild on 2026-09-22. The runtime switch, fonts and colors, and strings sections were read from the public source at tag `3.36.1` and build with `tools/curated/compile-snippets-ios.sh` (verified 2026-10-11). The message input colors and date format sections were read from the same tag and build the same way (verified 2026-10-12). GitHub source citations re-checked 2026-11-16 against tag `3.36.4`: the cited lines in `SBUGroupChannelListViewController.swift` (135–137) and `SBUAlertView.swift` (28, 289–307) are unchanged; 3.36.4 changes those files only at other lines. On 2026-11-23 the follow-system, bubble color, icon, default profile image, and RTL sections were added and the input bar restyle and date format rules were corrected, from the source at `3.36.1`; the cited lines are unchanged at `3.36.5`. Used by `/sendbird-client:ui-customize`. Do not invent API.

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

On the group channel screen, `updateStyles()` restyles the header and the message list but not the message input bar, so the input keeps the old colors. Call `setupStyles()` on its input view as well.

```swift
import UIKit
import SendbirdUIKit

@MainActor
func applySendbirdAppearance(isDark: Bool, visibleScreen: SBUBaseViewController?) {
    SBUTheme.set(colorScheme: isDark ? .dark : .light)             // 1. resets every component theme
    SBUTheme.channelTheme.leftBarButtonTintColor = .systemIndigo   // 2. re-apply your overrides
    visibleScreen?.updateStyles()                                  // 3. restyle what is on screen
    if let channelScreen = visibleScreen as? SBUGroupChannelViewController {
        (channelScreen.inputComponent?.messageInputView as? SBUMessageInputView)?.setupStyles()   // 4. the input bar
    }
}
```
Call it from your own appearance toggle, or from wherever your app observes the system appearance. The SDK's own doc comment on `set(colorScheme:)` describes the first three steps. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L82-L117; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUBaseViewController.swift#L116-L117 (`updateStyles()`); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L367-L383 (`updateStyles()` does not touch the input) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L39-L41 (`inputComponent`) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L902)

### Follow the system appearance
UIKit never watches the system appearance itself; no Sendbird screen observes trait changes. Observe it in your own container, for example the navigation controller that shows the Sendbird screens, and call the function above.

```swift
import UIKit
import SendbirdUIKit

final class ChatNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.appearanceDidChange()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        appearanceDidChange()
    }

    private func appearanceDidChange() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        for case let screen as SBUBaseViewController in viewControllers {
            applySendbirdAppearance(isDark: isDark, visibleScreen: screen)
        }
    }
}
```
Set the scheme once at launch too, from the window's `traitCollection.userInterfaceStyle`, before the first Sendbird screen. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L82-L117 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Util/SBUPropertyWrapper.swift#L65-L84 (screens read the current theme on every access) ; source: https://developer.apple.com/documentation/uikit/uitraitchangeobservable/registerfortraitchanges(_:handler:))

## Status bar style
iOS has no status bar color to set; a screen chooses dark or light status bar content through `preferredStatusBarStyle`. Each UIKit view controller returns its theme's `statusBarStyle` there, for example `SBUGroupChannelListTheme.statusBarStyle` on the channel list and `SBUChannelTheme.statusBarStyle` on the channel screen. The light themes use `.darkContent` and the dark themes use `.lightContent`. UIKit also extends `UINavigationController` so that it returns its top view controller's style, which makes the setting work inside a navigation controller. Set the style after `SBUTheme.set(colorScheme:)`, because that call replaces the theme objects.

```swift
import UIKit
import SendbirdUIKit

@MainActor
func useLightStatusBarContent() {
    SBUTheme.groupChannelListTheme.statusBarStyle = .lightContent
    SBUTheme.channelTheme.statusBarStyle = .lightContent
}
```
A screen that is already showing asks for the style again only after `setNeedsStatusBarAppearanceUpdate()` is called on it. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/SBUGroupChannelListViewController.swift#L135-L137; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L171-L173; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/UINavigationController%2BSBUIKit.swift#L12-L14; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L464-L470 (light `.darkContent`, dark `.lightContent` at line 495; static accessors at lines 231 and 252); SendbirdUIKit 3.36.2 `.swiftinterface` lines 14208, 14224, 14302 (`SBUGroupChannelListTheme`), 14401 (`SBUChannelTheme`); source: https://developer.apple.com/documentation/uikit/uiviewcontroller/setneedsstatusbarappearanceupdate())

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
The light themes take their accent (outgoing bubble, links) from `primaryMain`, but the dark themes take it from `primaryLight`. If you set only `primaryMain`, dark mode keeps the default purple, so set the whole primary ramp: `primaryExtraLight`, `primaryLight`, `primaryMain`, `primaryDark`, and `primaryExtraDark`.

`SBUFontSet` sets fonts for every screen at once. To change one place only, set the font property of that component theme after `set(colorScheme:)`, for example `SBUTheme.messageCellTheme.userMessageFont` (message text, default `body3`) or `SBUTheme.groupChannelCellTheme.titleFont` (channel names). UIKit does not support Dynamic Type: its fonts have fixed sizes, and a font from `UIFont.preferredFont(forTextStyle:)` is read once and does not follow a size change while the app runs. Set fonts before the first screen appears, because the line height of message text is taken from `SBUFontSet` the first time a message is drawn.

```swift
import UIKit
import SendbirdUIKit

SBUColorSet.primaryExtraLight = UIColor(red: 0.86, green: 0.90, blue: 1.0, alpha: 1)
SBUColorSet.primaryLight = UIColor(red: 0.44, green: 0.62, blue: 1.0, alpha: 1)   // dark mode accent
SBUColorSet.primaryMain = UIColor(red: 0.04, green: 0.36, blue: 1.0, alpha: 1)    // light mode accent
SBUColorSet.primaryDark = UIColor(red: 0.04, green: 0.28, blue: 0.66, alpha: 1)
SBUColorSet.primaryExtraDark = UIColor(red: 0.02, green: 0.16, blue: 0.40, alpha: 1)
SBUTheme.set(colorScheme: .light)
SBUTheme.messageCellTheme.userMessageFont = UIFont(name: "AvenirNext-Regular", size: 15) ?? SBUFontSet.body3
```
`SBUColorSet.primary300` and the other numbered primary colors are deprecated aliases of `primaryExtraLight`, `primaryLight`, `primaryMain`, and `primaryDark`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUColorSet.swift#L11-L27 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1514-L1592 (light: `rightBackgroundColor` and `linkColor` from `primaryMain`) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1713-L1789 (dark: from `primaryLight`) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1554 (`userMessageFont`) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUFontSet.swift#L15-L50 (fixed sizes; text attributes kept after the first read) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/ViewModel/SBUUserMessageTextViewModel.swift#L119 ; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/font-resources) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUFontSet.swift#L15-L231; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUColorSet.swift#L14-L18 (deprecated `primary300` at lines 173–177); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L583-L596 (a theme copies `SBUFontSet`/`SBUColorSet` when created; `shared` at line 333); source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/theme-resources)

## Message bubble colors
To recolor the bubbles without replacing the message cells, set the colors of `SBUTheme.messageCellTheme` after `set(colorScheme:)`. `rightBackgroundColor` and `rightPressedBackgroundColor` are your own (outgoing) messages, and `leftBackgroundColor` and `leftPressedBackgroundColor` are other users' (incoming) messages. Text colors are `userMessageRightTextColor` and `userMessageLeftTextColor`, and the "(edited)" label uses `userMessageRightEditTextColor` and `userMessageLeftEditTextColor`. File messages use the same left and right backgrounds. Open channels use `openChannelBackgroundColor` instead.

```swift
import UIKit
import SendbirdUIKit

SBUTheme.set(colorScheme: .light)   // first: it replaces messageCellTheme
let cellTheme = SBUTheme.messageCellTheme
cellTheme.rightBackgroundColor = .systemBlue
cellTheme.rightPressedBackgroundColor = .systemIndigo
cellTheme.userMessageRightTextColor = .white
cellTheme.leftBackgroundColor = UIColor(white: 0.93, alpha: 1)
cellTheme.userMessageLeftTextColor = .black
```
The defaults are `primaryMain` (light) or `primaryLight` (dark) for outgoing bubbles, and `background100` (light) or `background400` (dark) for incoming ones. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L2363-L2405 (the properties) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1514-L1558 (light defaults) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1713-L1756 (dark defaults) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUContentBaseMessageCell.swift#L310-L317 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/ViewModel/SBUUserMessageTextViewModel.swift#L86-L106)

## Icons
Every UIKit icon is a static `UIImage` of `SBUIconSet`, for example `iconSend`, `iconBack`, `iconMore`, `iconUser`, and `iconChat`. Assign your own images at launch, before the first screen is created; `SBUIconSet.restoreDefaultIcons()` puts the defaults back. UIKit tints and resizes an icon you assign, using the component theme's tint color (for example `SBUTheme.messageInputTheme.buttonTintColor` for the send button). Set `SBUGlobals.isTintColorEnabledForCustomizedIcon = false` to keep a multi-color image as it is, and `SBUGlobals.isCustomizedIconResizable = false` to keep its size.

```swift
import UIKit
import SendbirdUIKit

SBUIconSet.iconSend = UIImage(named: "brand-send") ?? SBUIconSet.iconSend
SBUGlobals.isTintColorEnabledForCustomizedIcon = false   // keep a multi-color asset as it is
SBUTheme.messageInputTheme.buttonTintColor = .systemBlue // tint for the icons that stay tinted
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUIconSet.swift#L12-L228 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Enums/SBUIconSetType.swift#L125-L150 (tint and resize) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SBUGlobals.swift#L155-L170 ; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/icon-resources)

## Default profile image and avatar shape
A user without a profile picture is shown with `SBUIconSet.iconUser` everywhere (message list, channel list, header, member lists), so replacing that icon changes the placeholder. Its colors in the message list are `SBUTheme.messageCellTheme.userPlaceholderBackgroundColor` and `userPlaceholderTintColor`.

Avatars are circles, and no theme property changes the shape: the message list and the channel list set the corner radius to half the image size in code. To change the shape, subclass the cell and set the radius after `super` (register the subclass as in knowledge/curated/ios/products/uikit.md, "How customization is wired").

```swift
import UIKit
import SendbirdUIKit
import SendbirdChatSDK

SBUIconSet.iconUser = UIImage(named: "avatar-placeholder") ?? SBUIconSet.iconUser

final class SquareAvatarUserMessageCell: SBUUserMessageCell {
    override func configureUserProfileView(message: BaseMessage) {
        super.configureUserProfileView(message: message)
        (profileView as? SBUMessageProfileView)?.imageView.layer.cornerRadius = 6
    }
}

final class SquareCoverChannelCell: SBUGroupChannelCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        coverImage.layer.cornerRadius = 8
    }
}
```
A channel with several members builds its cover from several image views; their own clipping was not checked. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUMessageProfileView.swift#L77-L101 (`iconUser` placeholder, radius from the size) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/SBUContentBaseMessageCell.swift#L676-L681 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/ChannelCell/SBUGroupChannelCell.swift#L233-L236 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/SBUCoverImageView.swift#L75-L122 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L1532-L1533 (placeholder colors))

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
`SBUDateFormatSet` holds the format strings UIKit uses for dates:

- `Message.sentTimeFormat` — the time under a message in group channels and threads, default `"hh:mm"`; `Message.sentTimeFormatInOpenChannel` for open channels.
- `Message.dateSeparatorDateFormat` (default `"E, MMM dd"`) and `Message.dateSeparatorPastYearFormat` (`"MMM dd, yyyy"`) — the date separators in the message list.
- `Channel.lastUpdatedTimeFormat` (`"hh:mm a"`), `Channel.lastUpdatedDateFormat` (`"MMM dd"`), and `Channel.lastUpdatedPastYearFormat` (`"yyyy/MM/dd"`) — the time of the last message in the channel list.

The two kinds are read differently. The message time goes through `DateFormatter.setLocalizedDateFormatFromTemplate(_:)`, so it is a template: the device locale decides the order and separators. The date separator and channel list formats are used exactly as written in a left-to-right app, so `"MMM dd"` prints in that order; only in a right-to-left app do they become templates. UIKit creates a new `DateFormatter` and never sets its `locale`, so the language of month and weekday names follows the device's current locale. "Yesterday" comes from `SBUStringSet.Date_Yesterday`.

```swift
import SendbirdUIKit

// Once at launch, before the first channel screen:
SBUDateFormatSet.Message.sentTimeFormat = "HH:mm"
SBUDateFormatSet.Message.sentTimeFormatInOpenChannel = "HH:mm"
SBUDateFormatSet.Message.dateSeparatorDateFormat = "yyyy-MM-dd (E)"
SBUDateFormatSet.Channel.lastUpdatedTimeFormat = "HH:mm"
SBUDateFormatSet.Channel.lastUpdatedDateFormat = "MM/dd"
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUDateFormatSet.swift#L36-L84 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/Date%2BSBUIKit.swift#L132-L175 (channel list and separators: a template only when the layout is right to left, line 139) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/Date%2BSBUIKit.swift#L160-L163 (`Date_Yesterday`) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/ChannelList/ChannelCell/SBUGroupChannelCell.swift#L469 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUMessageDateView.swift#L50)
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Constant/SBUDateFormatSet.swift#L50-L66; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/Date%2BSBUIKit.swift#L30-L38 (`sbu_toString(dateFormat:localizedFormat:)`, template by default); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUMessageStateView.swift#L170 (group channel time); source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageCell/OpenChannel/SBUOpenChannelContentBaseMessageCell.swift#L222 (open channel time); source: https://developer.apple.com/documentation/foundation/dateformatter/setlocalizeddateformatfromtemplate(_:); community context: https://github.com/sendbird/sendbird-uikit-ios/discussions/74)

## Right-to-left (RTL) layout
UIKit supports right-to-left languages since 3.25.0: message text and the input align by their first character, and reactions, menus, alerts, and date formats follow the layout direction. UIKit reads the direction from the key window's root view's `semanticContentAttribute` the first time it needs it, then keeps that value. So set the direction (or run the app in an RTL language) before the first Sendbird screen. Changing the direction inside the running app is not picked up until the app restarts. `UIView.setSemanticContentAttributeRecursively(view:attribute:)` applies an attribute to a view tree you build. No sendbird.com page documents RTL; the CHANGELOG does.

```swift
import UIKit
import SendbirdUIKit

@MainActor
func useRightToLeft(in window: UIWindow) {
    window.rootViewController?.view.semanticContentAttribute = .forceRightToLeft   // before the first Sendbird screen
}
```
(source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/CHANGELOG.md#L906-L908 (3.25.0) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Extension/Shared/UIView%2BSBUIKit.swift#L1353-L1388 (direction read once from the root view and kept) ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/CellView/SBUUserMessageTextView.swift#L193-L194 ; source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/MessageInput/SBUMessageInputView.swift#L958-L959)

## Pitfalls
- Set theme/color/font overrides before presenting the UIKit view controller.
- `navigationBarTintColor` on `SBUChannelTheme` and `SBUGroupChannelListTheme` is the bar's background color, not the button tint. Button colors are `leftBarButtonTintColor` and `rightBarButtonTintColor`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUBaseChannelViewController.swift#L353-L360)
- `SBUTheme.setOpenChannelList(channelListTheme:channelCellTheme:)` ignores both arguments in 3.36.1 through 3.36.5. Assign `SBUTheme.openChannelListTheme` and `SBUTheme.openChannelCellTheme` directly. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L127-L133)
- The sample code on the theme resources page uses deprecated names (`SBUChannelListTheme`, `SBUChannelCellTheme`, `setChannelList`, `primary300`). Use `SBUGroupChannelListTheme`, `SBUGroupChannelCellTheme`, `setGroupChannelList(channelListTheme:channelCellTheme:)`, and `primaryMain`. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Deprecated/SBUTheme.Deprecated.swift#L12-L19 ; source: https://sendbird.com/docs/chat/uikit/v3/ios-uikit/theme-and-style-resources/theme-resources)
- Apply your changes when the user toggles theme (it is not automatic).
- `SBUTheme.set(theme:)` and `SBUTheme.set(colorScheme:)` drop per-component colors you set earlier. Re-apply them after each call.
- Alert text unreadable in dark mode with a theme you built yourself: UIKit alerts (`SBUAlertView`) take their colors from `SBUTheme.componentTheme` (`alertTitleColor`, `alertDetailColor`). A `SBUComponentTheme` created with its initializer defaults to the light colors (`onLightTextHighEmphasis`, `onLightTextMidEmphasis`), while `SBUComponentTheme.dark` uses the dark ones. For dark mode, start from `SBUComponentTheme.dark` or set those two colors yourself. (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Common/AlertView/SBUAlertView.swift#L289-L307 (`theme` is `SBUTheme.componentTheme`, line 28); https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L3624-L3640 (initializer defaults), lines 3340–3362 (`dark`))

## Related
- UIKit: knowledge/curated/ios/products/uikit.md
