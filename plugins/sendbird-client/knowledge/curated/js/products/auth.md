<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js auth

> Auth is part of Chat, not a standalone product. Verified against sendbird.com/docs (Chat v4 JavaScript authentication, verified 2026-09-30); connect + SessionHandler + disconnect type-checked against `@sendbird/chat`. Cite each symbol; do not add API from memory.
> Primary source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication

## Overview

A user authenticates by connecting with a user ID and (for secured apps) an access/session token. A `SessionHandler` refreshes the token on expiry; disconnect on logout. Same for React and React Native (`@sendbird/chat` core).

## Connect (session token)

```ts
const user = await sb.connect(USER_ID, ACCESS_TOKEN);
```

(source: docs chat v4 javascript authentication)

## Token refresh — SessionHandler (set before connect)

```ts
import { SessionHandler } from '@sendbird/chat';

const handler = new SessionHandler();
handler.onSessionTokenRequired = (resolve, reject) => {
  // fetch a new token → resolve(NEW_TOKEN); resolve(null) to give up; reject(err) on error
};
handler.onSessionClosed = () => { /* route to login */ };
handler.onSessionRefreshed = () => {};
handler.onSessionError = (err) => {};
sb.setSessionHandler(handler);
```

(source: docs chat v4 javascript authentication — `SessionHandler`, `onSessionTokenRequired`/`onSessionClosed`/`onSessionRefreshed`/`onSessionError`, `sb.setSessionHandler(...)`; type-checked against @sendbird/chat)

## Session lifecycle

- A log-in session lasts ten minutes; the SDK refreshes it on its own with the session token it holds. Only when that token has expired or was revoked does the SDK call `onSessionTokenRequired(resolve, reject)`. Fetch a new token from your server and call `resolve(token)`, `resolve(null)` to give up, or `reject(err)` on failure. If you call neither before the refresh timeout, the socket is disconnected and you must call `sb.connect(USER_ID, TOKEN)` again. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication ; @sendbird/chat@4.22.13 lib/__definition.d.ts:4951-4968)
- Once an access token has been issued for a user, that user must pass a token to `sb.connect()`; connecting with the user ID alone is rejected. (source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication)
- From 4.22.6, session-key refresh and session revocation work even without a `SessionHandler`, but token renewal still needs `onSessionTokenRequired`. (source: @sendbird/chat CHANGELOG.md v4.22.6)

## Reauth / multi-device

- Reauth: on `onSessionClosed`, re-issue a token from your server and reconnect.
- Multi-device: the same `userId` can connect from multiple clients.

## Logout

```ts
await sb.disconnect();          // clears connection + local data
await sb.disconnectWebSocket(); // keep local cache
```

(source: docs chat v4 javascript authentication)

## Pitfalls

- Set the `SessionHandler` before `connect`.
- Tokens are secrets — never hard-code or log; issue from your server.

## Related

- Underlying Chat: knowledge/curated/js/products/chat.md
