<!-- status: populated -->
# templates/js/react-native/uikit

Sendbird UIKit on React Native (`@sendbird/uikit-react-native`). Container usage from the
public sample + docs-validation (verified 2026-06-09). `SendbirdUIKitContainer`,
`chatOptions.localCacheStorage`, and the public sample's native-service factory are type-checked by `compile-check-js.sh`.

## Files
- `App.tsx` — `<SendbirdUIKitContainer appId platformServices>`.
- `factory.ts` — native clipboard, notification, file, media, player, and recorder services from the public sample.
- `session.ts` — session tokens: `withSessionHandler(...)` for `chatOptions.onInitialized` (token refresh) and `useSendbirdSession()` to connect with `connect(userId, { accessToken })`.

## How to splice
1. Install the package + its peers/native modules per the quickstart (foundation, chat, RN modules).
2. Build `platformServices` from the SDK's `createNative*Service` factories — follow the quickstart, do not guess.
3. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; tokens are secrets.

## Session tokens (apps that require a token to connect)
The container initializes the Chat SDK but does not connect; the app connects from a component inside it. Details: knowledge/curated/js/products/uikit.md, "Session tokens: `connect(userId, { accessToken })` and `onInitialized`".
1. The customer's server issues the token for the signed-in user; the app fetches it after sign-in. Never ship the Platform API token or a fixed user token in the app.
2. Add `onInitialized: withSessionHandler({ getUserId, fetchToken, onSessionClosed })` to `chatOptions` next to `localCacheStorage`. It sets a `SessionHandler` on the new instance before any connect, and the handler asks `fetchToken` for a new token when the old one expired or was revoked. The container keeps these functions until it creates a new instance (only when `appId` changes), so they must read the current user from the app's auth store or a ref at call time, not a React state value captured in `App`.
3. After the app's own sign-in, call `signIn(userId, accessToken)` from `useSendbirdSession()` in a component inside the container. On sign-out call `signOut()`.
4. `onSessionClosed` sends the user back to the app's sign-in screen.
5. A full working app: `templates/starters-bp/react-native/App.tsx` and `src/sendbird/SessionBridge.tsx`.

## Variations (see knowledge/curated/js/products/uikit.md, all cited)
- Add UIKit fragments (e.g. group channel list) inside the container with navigation.
