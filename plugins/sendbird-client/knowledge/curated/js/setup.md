<!-- last-verified-against: @sendbird/chat 4.22.13 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — setup

> Package names verified by pinned and latest npm template type-checks on 2026-09-22. Cite each package; do not invent names.

> A plugin run does not build, compile, or type-check the project: do not run `npx tsc --noEmit`, `npm run build`, or `npm run typecheck` unless the customer asks for a build (`docs/AGENT_CONTRACT.md` section 3). The type-checks above are the plugin's own tests.

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

## App ID
Read the App ID the way the project already reads config. Detection writes the mechanism to `tier2.appIdSource` in the project profile (`tools/detection/tier2/detect-app-id-source.sh`). Never tell the customer to install a bundler or env loader just to read the App ID. App IDs are not secret; access and session tokens are, and never go into any of these.

| `appIdSource` | Variable in `.env.local` | Read in code | Source |
|---|---|---|---|
| `next` | `NEXT_PUBLIC_SENDBIRD_APP_ID` | `process.env.NEXT_PUBLIC_SENDBIRD_APP_ID` | https://nextjs.org/docs/app/guides/environment-variables |
| `expo` | `EXPO_PUBLIC_SENDBIRD_APP_ID` | `process.env.EXPO_PUBLIC_SENDBIRD_APP_ID` (dot notation only; `process.env[key]` is not inlined) | https://docs.expo.dev/guides/environment-variables/ |
| `vite` | `VITE_SENDBIRD_APP_ID` | `import.meta.env.VITE_SENDBIRD_APP_ID` | https://vite.dev/guide/env-and-mode |
| `cra` | `REACT_APP_SENDBIRD_APP_ID` | `process.env.REACT_APP_SENDBIRD_APP_ID` | https://create-react-app.dev/docs/adding-custom-environment-variables/ |
| `config` | none | export the value from a config module, e.g. `src/sendbird/config.ts` | no env loader was detected |

A request to read the App ID "from configuration" or "not as a literal" is met by the config module when `appIdSource` is `config`; do not switch to an env loader the project does not have, and do not suggest adding one in the answer, the manual steps, or the next steps.

Write the variable to `.env.local` at the project root, not to `.env`. All four loaders read `.env.local` in development and production builds (Next.js and Create React App skip it only when tests run), and it is the file their docs say to keep out of git (sources above). The plugin's starters ignore `.env`, `.env.local`, and `.env.*.local` in their .gitignore files; in another project, add `.env.local` to the project's .gitignore when it is not ignored yet. The App ID itself is not a secret, but a token someone adds to the same file later would be, so the file stays out of git from the start.

All four loaders inline the value at build time, so a changed env file needs a rebuild (sources above). The templates show `process.env.NEXT_PUBLIC_SENDBIRD_APP_ID` or `process.env.SENDBIRD_APP_ID`; replace that line with the row for the detected `appIdSource`.

## Pitfalls
- React Native peers must be installed + linked; don't skip `platformServices`/`nativeModules`.

## Related
- Chat: knowledge/curated/js/products/chat.md
- Hosts: knowledge/curated/js/hosts/react.md, react-native.md
