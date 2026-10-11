<!-- last-verified-against: n/a (conceptual host guidance) -->
<!-- status: populated -->
# ios host — UIKit

> Conceptual host guidance (no SDK API asserted). Verified 2026-06-10.

## Detection signals
- `import UIKit`, `UIApplicationDelegate` / `UIWindowSceneDelegate`, storyboards or programmatic view controllers, `AppDelegate`/`SceneDelegate`.

## Integration notes
- Sendbird UIKit + Calls/Desk/Live UIs are UIViewController-based — present/push them directly (see products/uikit.md).
- Initialize the SDK in `application(_:didFinishLaunchingWithOptions:)`; attach AI Agent launcher on the main thread.
- Lifecycle: add channel delegates in `viewWillAppear`, remove in `viewWillDisappear` (see cross-cutting/performance.md).

## Where common customizations live
- Message cells, including a custom file message cell or a cell for your own message type: knowledge/curated/ios/products/uikit.md, "Custom message cells".
- Input bar (extra buttons, removing the "+" button, attachment options, disabling input from app logic): knowledge/curated/ios/products/uikit.md, "Message input bar".
- Channel list item and loading indicator: knowledge/curated/ios/products/uikit.md, "Channel list".
- Navigation bar title and buttons: knowledge/curated/ios/products/uikit.md, "Header (navigation bar)".
- Thumbnails and video playback: knowledge/curated/ios/products/uikit.md, "Media: thumbnails and video".
- Dark mode at runtime, fonts, colors, strings and localization: knowledge/curated/ios/cross-cutting/theme.md.

## Related
- UIKit product: knowledge/curated/ios/products/uikit.md
- SwiftUI host: knowledge/curated/ios/hosts/swiftui.md
