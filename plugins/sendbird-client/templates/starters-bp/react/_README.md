<!-- status: populated -->
# React starter (best practice)

A small React (Vite + TypeScript) app with Sendbird Chat and UIKit wired the recommended way:
sign-in with a user ID, connect, a channel list next to the conversation, and sign-out. Start a new
app from this folder, then replace the user ID field with your own sign-in. The practices it follows
are listed in `../BEST_PRACTICES.md`.

## What is included

- `src/screens/LoginScreen.tsx` — the sign-in screen (user ID field, App ID check).
- `src/auth/session.ts` — the one app-wide session store; `src/auth/login.ts` — `onLoginSucceeded` / `onLogout` for your own sign-in.
- `src/auth/token.ts` — the hook that asks your server for a session token (returns none for now).
- `src/screens/SignedInApp.tsx` — `SendbirdProvider` (init + connect), the connection status line, `GroupChannelList` + `GroupChannel`, sign-out.
  Below 768px (`UIKIT_BREAKPOINT` in `src/sendbird/uikit.ts`) it shows one pane at a time: the list first, then the conversation, whose header back button returns to the list.
- `src/sendbird/config.ts` (App ID), `src/sendbird/uikit.ts` (theme, cache), `src/sendbird/errors.ts` (error codes).
- `package-lock.json` — exact dependency versions, so `npm ci` installs the same tree.

## Where each practice lives

| ID | File:line | What the code does |
|---|---|---|
| BP01 | `src/screens/SignedInApp.tsx:58` | One `SendbirdProvider` at the root of the signed-in tree; it reuses the cached Chat SDK instance. |
| BP02 | `src/sendbird/config.ts:3` | Reads `VITE_SENDBIRD_APP_ID`, inlined by Vite at build time; empty is reported on the sign-in screen. |
| BP03 | `src/auth/session.ts:45` | The provider mounts, and connects, only after `onLoginSucceeded(userId)`. |
| BP04 | `src/screens/SignedInApp.tsx:28` | `configureSession` returns a `SessionHandler`; the provider sets it before it connects. Token source: `src/auth/token.ts:3`. |
| BP05 | `src/screens/SignedInApp.tsx:58` | UIKit connects as the signed-in user (`userId`, `accessToken` props). |
| BP06 | `src/screens/SignedInApp.tsx:156` | The channel list mounts after the first successful connect. |
| BP07 | `src/screens/SignedInApp.tsx:92` | A `ConnectionHandler` drives the status line (Connected, Connecting…, Offline). |
| BP08 | `src/screens/SignedInApp.tsx:92` | The handler is added once the instance is ready and removed on unmount, under one identifier. |
| BP09 | `src/screens/SignedInApp.tsx:77` | Sign-out calls `disconnect()` on the connected instance. A browser has no FCM or APNs token to unregister. |
| BP11 | `src/sendbird/uikit.ts:23` | `localCacheEnabled: true` (already the React UIKit default). |
| BP12 | `src/sendbird/uikit.ts:8` | Theme and brand colors in one module, as constants. |
| BP13 | `src/sendbird/errors.ts:4` | Maps the verified error codes to a message; token errors return to sign-in (`src/screens/SignedInApp.tsx:43`). |
| BP16 | `src/auth/session.ts:1` | One store; every screen reads it with `useSession()`. |
| BP17 | `src/screens/LoginScreen.tsx:39` | Stable `data-testid` values (see below). |

Not applicable here: BP10 (browser web push is a separate service-worker setup), BP14 (SwiftUI), BP15 (React Native).

## Set the App ID

1. `cp .env.example .env.local`
2. Set `VITE_SENDBIRD_APP_ID=<your App ID>` in `.env.local` (not committed).
3. Restart `npm run dev` or rebuild: Vite inlines the value at build time.

The App ID is not a secret. Session and access tokens are, and never go into `.env` files.

## Run

```bash
npm ci
npm run dev        # http://localhost:5173
npm run build      # tsc --noEmit + vite build
```

## Stable identifiers

| Identifier | Element | Note |
|---|---|---|
| `sb_login_user_id` | user ID input (`#user`) | `src/screens/LoginScreen.tsx:39` |
| `sb_login_button` | Sign in button | `src/screens/LoginScreen.tsx:44` |
| `sb_app_id_missing` | missing App ID message | `src/screens/LoginScreen.tsx:30` |
| `sb_connection_status` | status line (`data-state` holds the SDK state) | `src/screens/SignedInApp.tsx:194` |
| `sb_channel_list` | container of the UIKit channel list | `src/screens/SignedInApp.tsx:160` |
| `sb_logout_button` | Sign out button | `src/screens/SignedInApp.tsx:152` |
| `sb_message_input`, `sb_send_button` | not set | UIKit renders the input; use its classes `.sendbird-message-input--textarea` and `.sendbird-message-input--send` (in `@sendbird/uikit-react/dist/index.css` 3.19.1). |
| `sb_open_channels` | not used | The web layout shows the channel list as soon as the user is connected. |

## Verified

Checked on 2026-10-14 with `@sendbird/chat` 4.22.13 and `@sendbird/uikit-react` 3.19.1:

- `npm ci && npm run build` — passes (`tsc --noEmit` clean, Vite build succeeds).
- Deprecated Sendbird APIs (TypeScript language service, the plugin's e2e check) — none.
- Runtime, against a test application: sign-in through the form, connect (the server reports the
  user online), a channel opened by a second user appears in the list and opens, the second user's
  message shows, a reply typed in the UIKit input reaches the server, and the second user's screen
  shows it. No uncaught or Sendbird console errors.
- Sign-out returns to the sign-in screen, the server reports the user offline, and a second user
  can sign in on the same page.

## Next steps

- Your sign-in: call `onLoginSucceeded(userId)` from `src/auth/login.ts` after it succeeds.
- Tokens: return a session token from your server in `src/auth/token.ts`
  (`knowledge/curated/js/products/auth.md`).
- Several tabs: add `supportMultipleTabs: true` in `src/sendbird/uikit.ts`
  (`knowledge/curated/js/hosts/react.md`).
- Theme and strings: `knowledge/curated/js/cross-cutting/theme.md`.
- Customizing UIKit screens: `knowledge/curated/js/products/uikit.md`.

(source: knowledge/curated/js/products/uikit.md)
(source: knowledge/curated/js/products/auth.md)
