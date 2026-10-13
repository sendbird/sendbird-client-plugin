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
- Init parameters and code that waits for initialization: knowledge/curated/ios/products/uikit.md, "Initialize (once, at launch)".
- Message cells, including a custom file message cell, a cell for your own message type, other text in a user message, leaving out the sender name or receipt icon, spacing between messages, and open channel cells: knowledge/curated/ios/products/uikit.md, "Custom message cells".
- Message order, long press, message menu items and events, reactions member list: knowledge/curated/ios/products/uikit.md, "Message list: order, menus, and taps".
- Input bar (extra buttons, your own "+" button or "+" sheet items, sending from your own flow, removing the "+" button, attachment options, text field height, voice message quality, open channel input styles, mention suggestions, disabling input from app logic): knowledge/curated/ios/products/uikit.md, "Message input bar".
- Channel list item, loading indicator, search, and a header above the rows: knowledge/curated/ios/products/uikit.md, "Channel list".
- Navigation bar title, buttons, and a tap on the title: knowledge/curated/ios/products/uikit.md, "Header (navigation bar)".
- Channel settings rows and the member list's right button: knowledge/curated/ios/products/uikit.md, "Channel settings and member list".
- Parent message at the top of a thread: knowledge/curated/ios/products/uikit.md, "Message threads".
- Thumbnails, video playback and sound, image viewer bottom bar: knowledge/curated/ios/products/uikit.md, "Media: thumbnails and video".
- Touches through the loading overlay, reading reaction emojis: knowledge/curated/ios/products/uikit.md, "Loading overlay and emojis".
- Dark mode at runtime, fonts, colors, message input colors, date and time formats, strings and localization: knowledge/curated/ios/cross-cutting/theme.md.

## Related
- UIKit product: knowledge/curated/ios/products/uikit.md
- SwiftUI host: knowledge/curated/ios/hosts/swiftui.md
