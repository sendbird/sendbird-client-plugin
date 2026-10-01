<!-- last-verified-against: n/a (conceptual architecture overview) -->
<!-- status: populated -->
# ios — architecture

> Conceptual overview of how the Sendbird iOS products layer together (no SDK API asserted). Verified 2026-06-10.

## Product layering
- **Chat (`SendbirdChatSDK`)** is the foundation — connection, channels, messages, and auth/session all live here.
- **UIKit (`SendbirdUIKit`)** builds prebuilt chat screens on top of Chat.
- **AI Agent (`SendbirdAIAgentMessenger`/Core)** is the flagship chatbot experience; its Core binary depends on Chat + UIKit.
- **Desk (`SendBirdDesk`)** is a support-ticketing plugin on top of Chat.
- **Calls (`SendBirdCalls`)** and **Live (`SendbirdLiveSDK`)** are separate WebRTC-based products (voice/video, streaming) that also pull Chat.

## Packaging
- Prefer Swift Package Manager. Calls/Live/AI Agent pull WebRTC and/or Chat transitively; their binary frameworks may need a device build (simulator slice arch limits).

## Detection / source priority
- The plugin detects host (UIKit/SwiftUI), package manager (SPM/CocoaPods), and products in use, then sources API from curated → customer-local SDK → public mirror/docs (see the iOS agent).

## Related
- Chat: knowledge/curated/ios/products/chat.md
- Setup: knowledge/curated/ios/setup.md
