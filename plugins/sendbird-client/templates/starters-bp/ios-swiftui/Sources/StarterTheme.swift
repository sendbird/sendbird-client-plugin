// source: knowledge/curated/ios/hosts/swiftui.md ("Theme, dark mode, strings")
import SendbirdSwiftUI

enum StarterTheme {
    /// BP12: the one place for the theme. Called once at launch, before SendbirdSwiftUI initializes
    /// and before the first Sendbird view appears. To restyle a screen that is already showing,
    /// set the theme again and give the root view a new identity (see the SwiftUI host doc).
    @MainActor
    static func apply() {
        SBUTheme.set(colorScheme: .light)
    }
}
