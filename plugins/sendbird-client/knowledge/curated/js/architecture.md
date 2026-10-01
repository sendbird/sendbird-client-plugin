<!-- last-verified-against: n/a (conceptual architecture overview) -->
<!-- status: populated -->
# js — architecture

> Conceptual overview of how the Sendbird JS products layer together (no SDK API asserted). Verified 2026-06-10.

## Product layering
- **Chat (`@sendbird/chat`)** is the platform-agnostic core — connection, channels, messages, auth/session. Same package on web (React) and React Native.
- **UIKit (`@sendbird/uikit-react` / `@sendbird/uikit-react-native`)** builds prebuilt chat UI on top of Chat.
- **AI Agent (`@sendbird/ai-agent-messenger-react` / `-react-native`)** is the flagship chatbot.
- **Calls (`sendbird-calls` web / `@sendbird/calls-react-native`)** and **Live (`@sendbird/live`)** are separate real-time products.
- **Desk (`sendbird-desk`)** is a support-ticketing plugin on top of Chat.

## Web vs React Native
- The Chat core is identical; only the surrounding UI + native modules differ. React UIKit needs CSS; RN UIKit/AI Agent need native modules + platform services.

## Detection / source priority
- The plugin detects host (React/React Native), package manager, and products, then sources API from curated → customer-local SDK (.d.ts) → public mirror/docs.

## Related
- Chat: knowledge/curated/js/products/chat.md
- Setup: knowledge/curated/js/setup.md
