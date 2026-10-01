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

## Related
- UIKit product: knowledge/curated/ios/products/uikit.md
- SwiftUI host: knowledge/curated/ios/hosts/swiftui.md
