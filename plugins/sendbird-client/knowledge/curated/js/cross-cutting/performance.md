<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-06-10 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# js — performance

> Anti-patterns for `/sendbird-client:performance-audit`. API names are delegated to the linked, version-watched Chat knowledge. Reviewed 2026-06-10. Do not invent API.

## Anti-patterns to flag
- **Repeated init.** `SendbirdChat.init(...)` once; reuse the returned `sb` instance. Re-init per render/component churns connections. (see knowledge/curated/js/products/chat.md)
- **Handler leaks.** Every `sb.groupChannel.addGroupChannelHandler(id, handler)` needs a matching `removeGroupChannelHandler(id)` on unmount (React `useEffect` cleanup) — otherwise stale handlers fire after unmount. (source: addGroupChannelHandler/removeGroupChannelHandler verified via code search)
- **Eager pagination.** Use collection/query objects with a `limit` and load-more; don't fetch all messages at once.
- **Unoptimized images.** Upload/display resized images in lists.
- **Re-creating modules.** Pass `modules` to `init` once; don't recreate `GroupChannelModule` repeatedly.

## Quick checklist
- One `init`, reuse `sb`.
- add/remove handler symmetric to component lifecycle.
- Pagination via query/collection limit.
- Image thumbnails in lists.

## Related
- Chat: knowledge/curated/js/products/chat.md
- Errors: knowledge/curated/js/cross-cutting/errors.md
