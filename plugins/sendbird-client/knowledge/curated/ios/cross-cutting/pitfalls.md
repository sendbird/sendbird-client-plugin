<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.10 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# ios — pitfalls

> Common iOS integration mistakes. Conceptual guidance; any API named is cited in the linked product docs. Verified 2026-06-10.

## Setup / packaging
- Use Swift Package Manager, not CocoaPods, for new projects (see knowledge/curated/ios/setup.md). Don't add `sendbird-chat-ios-spm` (legacy v3) for v4.
- Initialize once at launch; set `SBUGlobals.currentUser` (UIKit) before presenting any screen.

## Auth
- Register the `SessionDelegate` before `connect`, or token refresh won't wire up (see auth.md).
- Hard-coding access/session tokens or logging them — tokens are secrets, issue them from your server.

## Lifecycle / threading
- UI-touching SDK calls (e.g. AI Agent `attachLauncher`, presenting view controllers) must run on the main thread.
- Remove channel delegates you add (see performance.md) to avoid leaks.

## Calls / Live
- Calls/Live are SPM-only and pull WebRTC; their binary frameworks may need a device destination to build (simulator slice arch limits).

## Related
- Setup: knowledge/curated/ios/setup.md
- Performance: knowledge/curated/ios/cross-cutting/performance.md
