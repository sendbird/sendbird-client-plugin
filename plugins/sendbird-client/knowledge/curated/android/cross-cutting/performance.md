<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-06-10 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# android — performance

> Anti-patterns for `/sendbird-client:performance-audit`. API names are delegated to the linked, version-watched Chat knowledge. Reviewed 2026-06-10. Do not invent API.

## Anti-patterns to flag
- **Repeated init/connect.** Call `SendbirdChat.init` once in `Application.onCreate`; reuse the connection. (see knowledge/curated/android/products/chat.md)
- **Handler leaks.** Every `SendbirdChat.addChannelHandler(...)` needs a matching `SendbirdChat.removeChannelHandler(...)` bound to the Activity/Fragment lifecycle — otherwise leaked contexts and handlers firing on destroyed views. (source: addChannelHandler/removeChannelHandler verified via code search)
- **Eager pagination.** Use list queries with a `limit` + load-more on scroll.
- **Local caching off.** Enable caching in `InitParams(useCaching = true)` for offline data + fewer fetches. (see chat.md)
- **Unoptimized images.** Display resized thumbnails in lists.

## Quick checklist
- One `init`, one connection lifecycle.
- Symmetric add/remove handlers bound to the lifecycle.
- Pagination via query limit.
- Caching enabled; image thumbnails in lists.

## Related
- Chat: knowledge/curated/android/products/chat.md
- Errors: knowledge/curated/android/cross-cutting/errors.md
