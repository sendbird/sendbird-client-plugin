<!-- status: populated -->
# templates/js/react/uikit

Sendbird UIKit on React (`@sendbird/uikit-react`). From the public README (verified 2026-06-09).
**Type-checked** against the real package (v3.18.0, `tsc --noEmit` clean): `App` default export +
`appId`/`userId` props + the `dist/index.css` subpath.

## Files
- `App.tsx` — full drop-in `<SendbirdApp appId userId />`, with an optional `accessToken`.
- `SignedInChat.tsx` — `SendbirdProvider` with `accessToken` and `configureSession` (token refresh) for apps whose users connect with a token; put `GroupChannelList` / `GroupChannel` inside it.

## How to splice
1. `npm i @sendbird/uikit-react @sendbird/chat`
2. Render `<ChatApp />`; import `@sendbird/uikit-react/dist/index.css` (required, else unstyled).
3. App ID/user read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; tokens are secrets.

## Session tokens (apps that require a token to connect)
Splice this when the app already has its own sign-in and the Sendbird application requires an access or session token. Details: knowledge/curated/js/products/uikit.md, "Session tokens: `accessToken` and `configureSession`".
1. The customer's server issues the token for the signed-in user; the app fetches it after sign-in. Never put the Platform API token or a fixed user token in the bundle.
2. Render `<SignedInChat userId accessToken fetchToken onSessionClosed>` after sign-in and put the UIKit components inside it. It passes `accessToken` to `SendbirdProvider`, and `configureSession` returns a `SessionHandler` that asks `fetchToken` for a new token when the old one expired or was revoked.
3. `onSessionClosed` sends the user back to the app's sign-in screen.
4. The drop-in `App` takes `accessToken` but has no `configureSession` prop, so it cannot renew a token. If a token can expire while the page is open, use `SignedInChat` with the granular components.
5. A full working app: `templates/starters-bp/react/src/screens/SignedInApp.tsx`.

## Variations (see knowledge/curated/js/products/uikit.md, all cited)
- Granular UI: `SendbirdProvider` + `GroupChannelList` + `GroupChannel` (subpath imports, "Compose your own UI").
