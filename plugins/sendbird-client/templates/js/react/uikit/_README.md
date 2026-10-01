<!-- status: populated -->
# templates/js/react/uikit

Sendbird UIKit on React (`@sendbird/uikit-react`). From the public README (verified 2026-06-09).
**Type-checked** against the real package (v3.18.0, `tsc --noEmit` clean): `App` default export +
`appId`/`userId` props + the `dist/index.css` subpath.

## Files
- `App.tsx` — full drop-in `<SendbirdApp appId userId />`.

## How to splice
1. `npm i @sendbird/uikit-react @sendbird/chat`
2. Render `<ChatApp />`; import `@sendbird/uikit-react/dist/index.css` (required, else unstyled).
3. App ID/user from env — never hard-code; tokens are secrets.

## Variations (see knowledge/curated/js/products/uikit.md, all cited)
- Granular UI: `SendBirdProvider` + `ChannelList` + `Channel`.
