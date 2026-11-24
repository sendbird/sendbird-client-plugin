// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L82-L117 (set(colorScheme:) resets the component themes)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUFontSet.swift#L18-L232 (the 18 font slots and their default sizes and weights)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUColorSet.swift#L11-L27 (primary ramp; dark themes read primaryLight)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L2363-L2405 (message bubble colors)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/Channel/SBUGroupChannelViewController.swift#L367-L383 (updateStyles skips the input bar)
// Build-verified: xcodebuild BUILD SUCCEEDED against sendbird-uikit-ios-spm 3.36.1 and 3.36.5 (compile-check-ios.sh).
// Guide: knowledge/curated/ios/cross-cutting/theme.md ("Follow the system appearance", "Fonts and colors", "Message bubble colors").
//
// Dark mode that follows the system, brand colors, a custom font, and message bubble colors.
// Order: font and color sets first, then SBUTheme.set(colorScheme:), then per-component overrides,
// then restyle the screens that already exist.
import UIKit
import SendbirdUIKit

@MainActor
enum BrandChatTheme {
    // Brand palette. Replace with your own values.
    static let brand = UIColor(red: 0.00, green: 0.40, blue: 0.95, alpha: 1.0)
    static let brandPressed = UIColor(red: 0.00, green: 0.30, blue: 0.75, alpha: 1.0)
    static let brandLight = UIColor(red: 0.45, green: 0.65, blue: 1.00, alpha: 1.0)

    /// Call once at launch, before the first Sendbird screen is created.
    static func configureAtLaunch(style: UIUserInterfaceStyle) {
        applyFonts()
        applyColorSet()
        apply(isDark: style == .dark)
    }

    /// Step 1a: fonts. Every SBUFontSet slot is set, with the SDK's default size and weight, so
    /// headers, buttons, captions, and messages all use the brand family. `UIFont(name:size:)`
    /// returns nil when the font is not bundled (and listed under UIAppFonts in Info.plist), so the
    /// SDK default stays as the fallback. body3 is the message text (userMessageFont).
    static func applyFonts() {
        SBUFontSet.h1 = brandFont(.bold, 18, or: SBUFontSet.h1)
        SBUFontSet.h2 = brandFont(.medium, 18, or: SBUFontSet.h2)
        SBUFontSet.h3 = brandFont(.bold, 16, or: SBUFontSet.h3)
        SBUFontSet.body1 = brandFont(.regular, 16, or: SBUFontSet.body1)
        SBUFontSet.body2 = brandFont(.semibold, 14, or: SBUFontSet.body2)
        SBUFontSet.body3 = brandFont(.regular, 14, or: SBUFontSet.body3)
        SBUFontSet.body4 = brandFont(.bold, 14, or: SBUFontSet.body4)
        SBUFontSet.button1 = brandFont(.semibold, 18, or: SBUFontSet.button1)
        SBUFontSet.button2 = brandFont(.medium, 16, or: SBUFontSet.button2)
        SBUFontSet.button3 = brandFont(.medium, 14, or: SBUFontSet.button3)
        SBUFontSet.button4 = brandFont(.bold, 14, or: SBUFontSet.button4)
        SBUFontSet.caption1 = brandFont(.bold, 12, or: SBUFontSet.caption1)
        SBUFontSet.caption2 = brandFont(.regular, 12, or: SBUFontSet.caption2)
        SBUFontSet.caption3 = brandFont(.bold, 11, or: SBUFontSet.caption3)
        SBUFontSet.caption4 = brandFont(.regular, 11, or: SBUFontSet.caption4)
        SBUFontSet.subtitle1 = brandFont(.medium, 16, or: SBUFontSet.subtitle1)
        SBUFontSet.subtitle2 = brandFont(.regular, 16, or: SBUFontSet.subtitle2)
        SBUFontSet.subtitle3 = brandFont(.regular, 14, or: SBUFontSet.subtitle3)
    }

    /// The brand face for a weight. Replace the names with your own font's PostScript names.
    private static func brandFont(_ weight: UIFont.Weight, _ size: CGFloat, or fallback: UIFont) -> UIFont {
        let name: String
        switch weight {
        case .bold: name = "AvenirNext-Bold"
        case .semibold: name = "AvenirNext-DemiBold"
        case .medium: name = "AvenirNext-Medium"
        default: name = "AvenirNext-Regular"
        }
        return UIFont(name: name, size: size) ?? fallback
    }

    /// Step 1b: brand colors. The light themes use primaryMain for accents and outgoing bubbles;
    /// the dark themes use primaryLight. Set the whole ramp so both schemes pick up the brand.
    static func applyColorSet() {
        SBUColorSet.primaryExtraLight = brandLight.withAlphaComponent(0.35)
        SBUColorSet.primaryLight = brandLight
        SBUColorSet.primaryMain = brand
        SBUColorSet.primaryDark = brandPressed
        SBUColorSet.primaryExtraDark = brandPressed
    }

    /// Steps 2 and 3: rebuild the themes for the scheme, then re-apply per-component overrides.
    static func apply(isDark: Bool) {
        SBUTheme.set(colorScheme: isDark ? .dark : .light)

        let cell = SBUTheme.messageCellTheme
        cell.rightBackgroundColor = brand                    // outgoing bubble
        cell.rightPressedBackgroundColor = brandPressed
        cell.userMessageRightTextColor = .white              // outgoing text
        cell.leftBackgroundColor = isDark                    // incoming bubble
            ? UIColor(white: 0.22, alpha: 1.0)
            : UIColor(white: 0.93, alpha: 1.0)
        cell.userMessageLeftTextColor = isDark ? .white : .black

        SBUTheme.channelTheme.leftBarButtonTintColor = isDark ? brandLight : brand
        SBUTheme.channelTheme.rightBarButtonTintColor = isDark ? brandLight : brand
        SBUTheme.groupChannelListTheme.leftBarButtonTintColor = isDark ? brandLight : brand
        SBUTheme.groupChannelListTheme.rightBarButtonTintColor = isDark ? brandLight : brand
        SBUTheme.messageInputTheme.buttonTintColor = isDark ? brandLight : brand
    }

    /// Step 4: restyle Sendbird screens that already exist in a navigation stack.
    /// `updateStyles()` on the channel screen restyles the header and the message list but
    /// not the input bar, so the input view is restyled separately.
    static func restyle(_ viewControllers: [UIViewController]) {
        for viewController in viewControllers {
            guard let screen = viewController as? SBUBaseViewController else { continue }
            screen.updateStyles()
            if let channel = screen as? SBUGroupChannelViewController {
                (channel.inputComponent?.messageInputView as? SBUMessageInputView)?.setupStyles()
            }
            screen.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

/// A navigation controller for the Sendbird screens that follows the system appearance.
/// UIKit does not observe appearance changes itself, so this does it for the stack it owns.
final class BrandChatNavigationController: UINavigationController {
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
        if #available(iOS 17.0, *) { return }   // handled by registerForTraitChanges
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        appearanceDidChange()
    }

    private func appearanceDidChange() {
        BrandChatTheme.apply(isDark: traitCollection.userInterfaceStyle == .dark)
        BrandChatTheme.restyle(viewControllers)
    }
}

// Usage (e.g. in SceneDelegate, after SendbirdUI.initialize and setting SBUGlobals.currentUser):
//
//   BrandChatTheme.configureAtLaunch(style: window.traitCollection.userInterfaceStyle)
//   let channelList = SBUGroupChannelListViewController()
//   window.rootViewController = BrandChatNavigationController(rootViewController: channelList)
