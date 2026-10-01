<!-- last-verified-against: sendbird-swiftui-ios 1.2.2 / sendbird-calls-ios 1.12.3 / sendbird-live-sdk-ios 1.6.0 -->
<!-- status: populated -->
# ios host — SwiftUI

> Host guidance. The SendbirdSwiftUI sections are read from the public `sendbird-swiftui-ios` 1.2.2 package (swiftinterface and source) and their snippet is build-verified (xcodebuild). Verified 2026-09-30.

## Detection signals
- `import SwiftUI`, `App` protocol with `@main`, `WindowGroup`, `some View`, `@UIApplicationDelegateAdaptor` for an AppDelegate bridge.

## Integration notes
- Sendbird UIKit (`SendbirdUIKit`) and AI Agent screens are UIViewController-based. Wrap them in `UIViewControllerRepresentable` (standard interop, not an SDK API).
- Calls and Live ship no prebuilt screens; their video views (`SendBirdVideoView` in SendBirdCalls, `SendbirdVideoView` in SendbirdLiveSDK) are UIViews, so wrap them in `UIViewRepresentable`. Desk is headless and needs no wrapper. (source: SendBirdCalls.swiftinterface (1.12.3) line 450; SendbirdLiveSDK.swiftinterface (1.6.0) line 606; build-verified SwiftUI templates in templates/ios/swiftui/calls, templates/ios/swiftui/live, templates/ios/swiftui/desk)
- Chat also ships SwiftUI-native views in the separate `SendbirdSwiftUI` package; see SwiftUI-native chat views (SendbirdSwiftUI) below. A build-verified template is in templates/ios/swiftui/uikit.
- The AI Agent floating launcher attaches to the window, so it works from a SwiftUI app run from an `@UIApplicationDelegateAdaptor` AppDelegate (see products/ai-agent.md + templates/ios/swiftui/ai-agent/_README.md).
- Init/connect/auth APIs are identical to the UIKit host.

## SwiftUI-native chat views (SendbirdSwiftUI)

Sendbird ships SwiftUI views for Chat in a separate package: add `https://github.com/sendbird/sendbird-swiftui-ios` and use the product `SendbirdSwiftUI` (iOS 15+). The docs state it currently supports iPhone only, not iPad. Views such as `GroupChannelListView` are SwiftUI `View`s, so they need no `UIViewControllerRepresentable` wrapper.

(source: sendbird/sendbird-swiftui-ios Package.swift (1.2.2); SendbirdSwiftUI.swiftinterface (1.2.2) line 897; https://sendbird.com/docs/chat/uikit/v3/swiftui/essentials/installation)

## Switching users and keeping custom views

When the signed-in user changes, bind the Sendbird root view's identity to the user ID with SwiftUI's `.id(_:)`; a new identity makes SwiftUI rebuild the view and reset its state, so the next user starts from a fresh `GroupChannelListView`. SendbirdSwiftUI resets customized view adaptors whenever a SendbirdSwiftUI view's `onDisappear` is called; to keep them, set `GlobalOptions.enableViewAdaptorAutoReset = false` before that view appears (for app-wide behavior, before `SendbirdUI.initialize`).

```swift
import SwiftUI
import SendbirdSwiftUI

// Call once at launch (e.g. from application(_:didFinishLaunchingWithOptions:)),
// before any SendbirdSwiftUI view appears.
func configureSendbird() {
    GlobalOptions.enableViewAdaptorAutoReset = false
    SendbirdUI.initialize(applicationId: "APP_ID") { error in }
}

struct ChatRoot: View {
    let userId: String
    var body: some View {
        GroupChannelListView()
            .id(userId)   // new user ID -> new view identity -> fresh state
    }
}
```

(source: SendbirdSwiftUI.swiftinterface (1.2.2) lines 673–674, 897–898, 21358; sendbird/sendbird-swiftui-ios@1.2.2 Sources/SwiftUI/Common/GlobalOptions.swift lines 13–17; https://developer.apple.com/documentation/swiftui/view/id(_:))

## Related
- UIKit host: knowledge/curated/ios/hosts/uikit.md
- AI Agent: knowledge/curated/ios/products/ai-agent.md
