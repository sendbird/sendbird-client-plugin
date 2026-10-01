<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — setup

> Package names verified by pinned and latest npm template type-checks on 2026-09-22. Cite each package; do not invent names.

## Packages (npm)
- Chat (core): `@sendbird/chat`
- UIKit: `@sendbird/uikit-react` (web) / `@sendbird/uikit-react-native` (RN)
- AI Agent: `@sendbird/ai-agent-messenger-react` / `@sendbird/ai-agent-messenger-react-native`
- Calls: `sendbird-calls` (web) / `@sendbird/calls-react-native` (RN)
- Desk: `sendbird-desk`
- Live: `@sendbird/live`

## Init
- `SendbirdChat.init({ appId, modules: [...] })` once; reuse the `sb` instance.
- React UIKit needs the CSS import (`@sendbird/uikit-react/dist/index.css`).
- React Native needs native modules / platform services per the quickstart (mmkv, safe-area, etc.).

## Pitfalls
- App ID from env (e.g. `NEXT_PUBLIC_SENDBIRD_APP_ID`); tokens are secrets.
- React Native peers must be installed + linked; don't skip `platformServices`/`nativeModules`.

## Related
- Chat: knowledge/curated/js/products/chat.md
- Hosts: knowledge/curated/js/hosts/react.md, react-native.md
