// source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sources/SwiftUI/Theme/ColorSet.swift#L11-L35 (ColorSet writes the UIKit color set)
// source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sources/SwiftUI/Theme/FontSet.swift#L13-L115 (every FontSet slot converts with asUIFont())
// source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sources/SwiftUI/Extension/UIFont%2BSendbird.swift#L47-L99 (which Font values convert)
// source: https://github.com/sendbird/sendbird-swiftui-ios/blob/1.2.2/Sources/uikit/Theme/SBUTheme.swift (SBUTheme, messageCellTheme)
// Build-verified: xcodebuild BUILD SUCCEEDED against sendbird-swiftui-ios 1.2.2 and 1.2.4 (compile-check-ios.sh).
// Guide: knowledge/curated/ios/hosts/swiftui.md ("Theme, dark mode, strings").
//
// Brand colors, a custom font, and message bubble colors for SendbirdSwiftUI, with dark mode from
// the SwiftUI color scheme. The SwiftUI views do not restyle themselves when the scheme changes, so
// BrandChatListScreen creates the list again with a new identity. That part compiles but was not run
// on a device; check how a pushed channel screen behaves before shipping it.
import SwiftUI
import UIKit
import SendbirdSwiftUI

@MainActor
enum BrandChatTheme {
    static let brand = Color(red: 0.00, green: 0.40, blue: 0.95)
    static let brandPressed = Color(red: 0.00, green: 0.30, blue: 0.75)
    static let brandLight = Color(red: 0.45, green: 0.65, blue: 1.00)

    /// Call before the first SendbirdSwiftUI view is created (for example in the App's init).
    static func configureAtLaunch(isDark: Bool) {
        applyFonts()
        applyColorSet()
        apply(isDark: isDark)
    }

    /// FontSet setters convert with asUIFont(). Font.custom(_:size:) maps to UIFont(name:size:);
    /// when that font is not bundled, the SDK logs a warning and falls back to the body text style.
    /// Every slot is set, with the SDK's default size and weight, so headers, buttons, captions,
    /// and messages all use the brand family. body3 is the message text.
    static func applyFonts() {
        let bold = "AvenirNext-Bold", semibold = "AvenirNext-DemiBold"
        let medium = "AvenirNext-Medium", regular = "AvenirNext-Regular"
        FontSet.h1 = Font.custom(bold, size: 18)
        FontSet.h2 = Font.custom(medium, size: 18)
        FontSet.h3 = Font.custom(bold, size: 16)
        FontSet.body1 = Font.custom(regular, size: 16)
        FontSet.body2 = Font.custom(semibold, size: 14)
        FontSet.body3 = Font.custom(regular, size: 14)
        FontSet.body4 = Font.custom(bold, size: 14)
        FontSet.button1 = Font.custom(semibold, size: 18)
        FontSet.button2 = Font.custom(medium, size: 16)
        FontSet.button3 = Font.custom(medium, size: 14)
        FontSet.button4 = Font.custom(bold, size: 14)
        FontSet.caption1 = Font.custom(bold, size: 12)
        FontSet.caption2 = Font.custom(regular, size: 12)
        FontSet.caption3 = Font.custom(bold, size: 11)
        FontSet.caption4 = Font.custom(regular, size: 11)
        FontSet.subtitle1 = Font.custom(medium, size: 16)
        FontSet.subtitle2 = Font.custom(regular, size: 16)
        FontSet.subtitle3 = Font.custom(regular, size: 14)
    }

    static func applyColorSet() {
        ColorSet.primaryExtraLight = brandLight.opacity(0.35)
        ColorSet.primaryLight = brandLight
        ColorSet.primaryMain = brand
        ColorSet.primaryDark = brandPressed
        ColorSet.primaryExtraDark = brandPressed
    }

    static func apply(isDark: Bool) {
        SBUTheme.set(colorScheme: isDark ? .dark : .light)

        let cell = SBUTheme.messageCellTheme
        cell.rightBackgroundColor = brand.asUIColor()                 // outgoing bubble
        cell.rightPressedBackgroundColor = brandPressed.asUIColor()
        cell.userMessageRightTextColor = Color.white.asUIColor()      // outgoing text
        cell.leftBackgroundColor = (isDark ? Color(white: 0.22) : Color(white: 0.93)).asUIColor()
        cell.userMessageLeftTextColor = (isDark ? Color.white : Color.black).asUIColor()

        let accent = (isDark ? brandLight : brand).asUIColor()
        SBUTheme.channelTheme.leftBarButtonTintColor = accent
        SBUTheme.channelTheme.rightBarButtonTintColor = accent
        SBUTheme.groupChannelListTheme.leftBarButtonTintColor = accent
        SBUTheme.groupChannelListTheme.rightBarButtonTintColor = accent
        SBUTheme.messageInputTheme.buttonTintColor = accent
    }
}

/// Shows the channel list and re-themes it when the system appearance changes.
struct BrandChatListScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var themedScheme: ColorScheme?

    var body: some View {
        GroupChannelListView()
            // A new identity makes SwiftUI create the view again, so its UIKit screen is built
            // from the current SBUTheme. Everything under it is recreated too (the list reloads).
            // Not run on a device: check what happens to a channel screen pushed from this list.
            .id(themedScheme)
            .onAppear { applyIfNeeded(colorScheme) }
            .onChange(of: colorScheme) { newValue in applyIfNeeded(newValue) }
    }

    private func applyIfNeeded(_ scheme: ColorScheme) {
        guard themedScheme != scheme else { return }
        BrandChatTheme.apply(isDark: scheme == .dark)
        themedScheme = scheme
    }
}

// Usage:
//
//   @main
//   struct MyApp: App {
//       init() {
//           BrandChatTheme.configureAtLaunch(
//               isDark: UITraitCollection.current.userInterfaceStyle == .dark
//           )
//           // SendbirdUI.initialize(...) after this
//       }
//       var body: some Scene { WindowGroup { BrandChatListScreen() } }
//   }
