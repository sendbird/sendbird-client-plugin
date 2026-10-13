// source: https://github.com/sendbird/sendbird-uikit-ios (README quickstart, verified 2026-06-09)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SBUGlobals.swift#L22-L26 (accessToken, currentUser)
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/Theme/SBUTheme.swift#L252 (channelTheme)
// Build-verified: SendbirdUI.initialize / SBUGlobals.currentUser / SBUUser /
// SBUGroupChannelListViewController compile + link against SendbirdUIKit (xcodebuild
// BUILD SUCCEEDED, 2026-06-09). SPM: sendbird-uikit-ios-spm, product SendbirdUIKit.
// App ID from env; access token is a secret — never hard-code.

import Foundation
import UIKit
import SendbirdUIKit

private let appId = ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"

enum SendbirdUIKitBootstrap {
    // Call once at launch (application(_:didFinishLaunchingWithOptions:)).
    static func initialize() {
        SBUTheme.set(colorScheme: .light)
        SBUTheme.channelTheme.leftBarButtonTintColor = .black
        SendbirdUI.initialize(applicationId: appId) {
            // started
        } migrationHandler: {
            // migration progress
        } completionHandler: { error in
            if let error = error { print("UIKit init failed: \(error)") }
        }
    }

    // Required before presenting any UIKit screen.
    static func setCurrentUser(userId: String, nickname: String? = nil) {
        SBUGlobals.currentUser = SBUUser(userId: userId, nickname: nickname)
        // Authenticated apps: SBUGlobals.accessToken = TOKEN
    }

    // Present the prebuilt group channel list.
    static func presentChannelList(from presenter: UIViewController) {
        let listVC = SBUGroupChannelListViewController()
        let nav = UINavigationController(rootViewController: listVC)
        presenter.present(nav, animated: true)
    }
}
