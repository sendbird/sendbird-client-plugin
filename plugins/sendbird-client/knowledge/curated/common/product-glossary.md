<!-- last-verified-against: conceptual -->
<!-- verified-at: 2026-09-22 -->
<!-- status: populated -->
# Sendbird — Product Glossary

## Overview
How the products relate, conceptually. No API signatures here.

## Products
- Chat: messaging core. The connection/session ("auth") layer is part of Chat, not a separate product.
- UIKit: drop-in UI built on Chat. Hosts: iOS UIKit/SwiftUI, Android View/Compose, JS React/React-Native.
- AI Agent: AI conversation product with its own UI concepts — Conversation (its chat surface), Conversation List, and Launcher (the entry-point widget). Distinct from Chat's channel/message vocabulary.
- Desk: customer-support tickets and routing.
- Calls: direct and group voice/video.
- Live: host/audience live streaming.

## Platform availability (v0.1 plugin scope)
Codegen: Chat, UIKit, AI Agent, Desk, Calls, Live across iOS (UIKit+SwiftUI), Android (View+Compose), JS (React+RN). PlatformX (Flutter/Unity/.NET/Unreal) is lookup-only at v0.1.

## Related
- Official docs: https://sendbird.com/docs
