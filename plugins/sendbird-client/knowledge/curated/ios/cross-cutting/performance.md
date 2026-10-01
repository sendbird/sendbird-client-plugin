<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.10 -->
<!-- verified-at: 2026-06-10 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# ios — performance

> Anti-patterns for `/sendbird-client:performance-audit`. API names are delegated to the linked, version-watched Chat knowledge. Reviewed 2026-06-10. Do not invent API.

## Anti-patterns to flag
- **Repeated init/connect.** Call `SendbirdChat.initialize` once at launch; reuse the connection. Re-initializing per screen churns the websocket. (see knowledge/curated/ios/products/chat.md)
- **Delegate leaks.** Every `SendbirdChat.addChannelDelegate(_:identifier:)` needs a matching `SendbirdChat.removeChannelDelegate(forIdentifier:)` when the screen goes away — otherwise retained controllers leak and handlers fire on dead views. (source: addChannelDelegate/removeChannelDelegate verified via code search)
- **Eager pagination.** Use the SDK's message/channel list queries with a sensible `limit` and load more on scroll; don't fetch everything up front.
- **Local caching off.** `InitParams(isLocalCachingEnabled: true)` gives offline data + fewer fetches. (see chat.md; build-verified there)
- **Unoptimized images.** Send/display resized thumbnails, not full-resolution originals, in lists.

## Quick checklist
- One `initialize`, one connection lifecycle.
- Symmetric add/remove for every delegate identifier.
- Pagination via query limit; reuse query objects.
- Local caching enabled; image thumbnails in lists.

## Related
- Chat: knowledge/curated/ios/products/chat.md
- Errors: knowledge/curated/ios/cross-cutting/errors.md
