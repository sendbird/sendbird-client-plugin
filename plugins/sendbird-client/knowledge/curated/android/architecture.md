<!-- last-verified-against: n/a (conceptual architecture overview) -->
<!-- status: populated -->
# android — architecture

> Conceptual overview of how the Sendbird Android products layer together (no SDK API asserted). Verified 2026-06-10.

## Product layering
- **Chat (`com.sendbird.sdk:sendbird-chat`)** is the foundation — connection, channels, messages, auth/session.
- **UIKit (`com.sendbird.sdk:uikit`)** builds prebuilt chat screens on top of Chat (View/Fragment-based, ViewBinding).
- **Desk** is a support-ticketing plugin on top of Chat.
- **Calls** and **Live** are WebRTC-based products (voice/video, streaming).

## Packaging
- Gradle from `repo.sendbird.com`. UIKit needs ViewBinding + Java 11 + API 21+.

## Detection / source priority
- The plugin detects host (View/Compose), Gradle setup, and products, then sources API from curated → customer-local SDK → public mirror/docs.

## Related
- Chat: knowledge/curated/android/products/chat.md
- Setup: knowledge/curated/android/setup.md
