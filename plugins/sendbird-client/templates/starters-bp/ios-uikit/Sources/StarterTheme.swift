// source: knowledge/curated/ios/cross-cutting/theme.md ("Light / dark", "Per-component overrides")
import SendbirdUIKit

enum StarterTheme {
    /// BP12: the one place for the UIKit theme. Called once at launch, before the first UIKit
    /// screen is created. To follow the system appearance at runtime, see the theme doc.
    @MainActor
    static func apply() {
        SBUTheme.set(colorScheme: .light)
        // Per-component overrides go after set(colorScheme:), for example:
        // SBUTheme.channelTheme.leftBarButtonTintColor = .systemIndigo
    }
}
