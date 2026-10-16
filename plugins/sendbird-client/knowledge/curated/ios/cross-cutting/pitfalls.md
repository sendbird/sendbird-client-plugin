<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 / sendbird-uikit-ios 3.36.1 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# ios — pitfalls

> Common iOS integration mistakes. Conceptual guidance; any API named is cited in the linked product docs. Verified 2026-06-10.

## Setup / packaging
- Use Swift Package Manager, not CocoaPods, for new projects (see knowledge/curated/ios/setup.md). Don't add `sendbird-chat-ios-spm` (legacy v3) for v4. To move a v3 app to v4, see knowledge/curated/ios/cross-cutting/migration.md.
- Initialize once at launch; set `SBUGlobals.currentUser` (UIKit) before presenting any screen.

## Auth
- Register the `SessionDelegate` before `connect`, or token refresh won't wire up (see auth.md).
- Hard-coding access/session tokens or logging them — tokens are secrets, issue them from your server.

## Lifecycle / threading
- UI-touching SDK calls (e.g. AI Agent `attachLauncher`, presenting view controllers) must run on the main thread.
- Remove channel delegates you add (see performance.md) to avoid leaks.
- Remove delegates by the identifier you added them with. The remove-all calls (`SendbirdChat.removeAllConnectionDelegates()`, `removeAllChannelDelegates()`, `removeAllUserEventDelegates()`) also remove delegates that other code registered. With UIKit this matters for connection delegates: UIKit's channel list and channel view models add their own with `SendbirdChat.addConnectionDelegate(_:identifier:)`, and on `didSucceedReconnection()` they report the connection state to the channel list and refresh the open channel, so `removeAllConnectionDelegates()` stops both. (source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/ChannelList/SBUBaseChannelListViewModel.swift#L38-L41 — channel list, reconnection at lines 98–110) (source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/ViewModel/Channel/SBUBaseChannelViewModel.swift#L186-L189 — channel, `refreshChannel()` after reconnection at lines 1084–1096) (source: SendbirdChatSDK 4.39.11 SendbirdChatSDK.swiftinterface:6368 `addConnectionDelegate(_:identifier:)`, :6369 `removeConnectionDelegate(forIdentifier:)`, :6373, :6381, :6389)

## Calls / Live
- Calls/Live are SPM-only and pull WebRTC; their binary frameworks may need a device destination to build (simulator slice arch limits).

## Related
- Setup: knowledge/curated/ios/setup.md
- Performance: knowledge/curated/ios/cross-cutting/performance.md
