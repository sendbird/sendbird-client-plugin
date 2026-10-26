---
name: ui-customize
description: Customize Sendbird UIKit UI — theme, colors, fonts, dark mode, navbar, message bubble, and component replacement — for the detected host. Use when the customer wants to restyle or override Sendbird UI, including changing or replacing parts of the chat screens such as the header, channel list items or cells, badges, the input bar, or the message menu, even when the request does not say Sendbird.
argument-hint: "[--product uikit]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:ui-customize

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done. When the agent reports, your final answer carries its changed files, every check line, and its symbol, source, and version table as the agent wrote them (`docs/AGENT_CONTRACT.md` section 6); shorten the wording only.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed. Only for "out of configured scope" add that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; for "not available on this host" give the reason it printed and never suggest those settings, which cannot change it; a non-interactive run ends with `status: "declined"`.

Theme / override Sendbird UI for the detected platform + host + product.

## Steps
1. Detect platform/host and confirm the UI product is UIKit. Ask once if ambiguous.
2. In this session and before the hand-off in step 4, read the wired curated docs below for the request, then run `bash "${CLAUDE_PLUGIN_ROOT}/core/commands/search-discussions.sh" <owner/repo> <English keywords>` once on the relevant UIKit / SwiftUI mirror (the repository from `config/plugin-config.json` `.repos`). Put the curated sections and the discussion results, or the `NOT RUN: <reason>` line, in the agent's brief. Label what a discussion says as community signal; when the command prints `NOT RUN: <reason>`, say in the answer that discussions were not searched and why.
3. Check every theme, component, or slot name in the installed SDK before it is used: `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project-dir> uikit [resolved-version]`. When the SDK is not installed, say so and use only names a curated section states, with that section's SDK version. Do not download an SDK yourself to use as evidence.
4. Hand off to the platform agent to generate the override (theme/colorset/fontset or component/slot replacement) from a verified pattern, host-correct. When the project has no Sendbird UIKit package (chat screens built on the Chat SDK, restyled in their own code), the brief also tells the agent to type-check the files it changed: `bash "${CLAUDE_PLUGIN_ROOT}/tools/verify/check-written.sh" <project-dir> <every .ts, .tsx, .kt, .java, and .swift file changed>`, fix the errors it lists in those files, and run it again, up to three runs (contract section 3, "Type-check the Chat SDK screens you wrote"); report the result as the check `typecheck`. A UIKit or AI Agent theme does not run it. The brief says: change only the Sendbird screens the request names. The app's own screens (sign-in, home, settings) stay as they are unless the request asks for them too; then their colors come from one theme module of the app (for example `theme.ts` or a `Theme` object) that the screens import, never hex values or inline colors written into each screen.
5. Report the change, then end the answer with all five rows of the table below for the detected host, one line each in this order: dark mode, brand colors, fonts, message bubble, header. Each line names the curated file and section heading from the table (for a cell that says there is no curated section, say so on that line); do not shorten the list or drop a row because the request touched only one of them. After the five lines, add one line naming the deeper replacement path (React render props, iOS subclass or slot, Android custom view or Compose slot).
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): the five lines stay in the answer text, before the run summary block; the run summary does not replace them.

| Tweak | iOS | Android | JS |
| --- | --- | --- | --- |
| Dark mode | `cross-cutting/theme.md` "Light / dark"; SwiftUI `hosts/swiftui.md` "Theme, dark mode, strings" | `cross-cutting/theme.md` "Light / dark (View host)"; Compose `hosts/compose.md` "Theme, fonts, and strings" | `cross-cutting/theme.md` "Light / dark" (React), "Light / dark and custom colors" (React Native) |
| Brand colors | `cross-cutting/theme.md` "Fonts and colors" | `cross-cutting/theme.md` "Custom colors (View host)"; Compose as above | `cross-cutting/theme.md` "Brand colors (`colorSet`) and strings (`stringSet`)" (React), "Light / dark and custom colors" (React Native) |
| Fonts | `cross-cutting/theme.md` "Fonts and colors" | `cross-cutting/theme.md` "Fonts (View host)"; Compose as above | no curated section: say so |
| Message bubble | `products/uikit.md` "Custom message cells"; SwiftUI `hosts/swiftui.md` "Custom message views, including file messages and reply thumbnails" | `products/uikit.md` "Custom message views, including file messages (View host)"; Compose `hosts/compose.md` "Custom message items, including file messages" | `products/uikit.md` "Customize how messages render" |
| Header | `products/uikit.md` "Header (navigation bar)"; SwiftUI `hosts/swiftui.md` "Header" | `products/uikit.md` "Header (View host)"; Compose `hosts/compose.md` "Header (top bar)" | `products/uikit.md` "Channel header" |

Paths in the table are under `knowledge/curated/<platform>/`.

## Wired knowledge (populated and cited)
- UIKit theming: `knowledge/curated/<platform>/cross-cutting/theme.md` — iOS `SBUTheme.set(colorScheme:)` + per-component themes; Android `SendbirdUIKit.setDefaultThemeMode(...)`; JS `<App theme="light|dark">` + `--sendbird-*` CSS vars; RN foundation themes.
- iOS UIKit components: `knowledge/curated/ios/products/uikit.md` — custom message cells (including file messages), input bar buttons and attachment options, disabling input, channel list item and loading indicator, header, thumbnails, video playback. iOS theme at runtime, fonts, strings: `knowledge/curated/ios/cross-cutting/theme.md`.
- iOS SwiftUI (SendbirdSwiftUI): `knowledge/curated/ios/hosts/swiftui.md` — `headerItem`/`listItem`/`inputItem` builders for message views, reply thumbnails, input buttons, channel-list search and loading, header, theme.
- UIKit component customization (JS): `knowledge/curated/js/products/uikit.md` — React render props and React Native fragment modules for message rendering (including file messages), the message input, the channel list (custom row, filter, loading state), and the channel header.

## No-Fabrication
Theme/override symbols must be verified for the host (no invented theme APIs). Uncited -> fetch the verified source or decline. Cite each symbol.
