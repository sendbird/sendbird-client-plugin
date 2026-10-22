---
name: ui-customize
description: Customize Sendbird UIKit UI — theme, colors, fonts, dark mode, navbar, message bubble, and component replacement — for the detected host. Use when the customer wants to restyle or override Sendbird UI, including changing or replacing parts of the chat screens such as the header, channel list items or cells, badges, the input bar, or the message menu, even when the request does not say Sendbird.
argument-hint: "[--product uikit]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:ui-customize

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed (out of the configured scope, or not supported yet) and that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; a non-interactive run ends with `status: "declined"`.

Theme / override Sendbird UI for the detected platform + host + product.

## Steps
1. Detect platform/host and confirm the UI product is UIKit. Ask once if ambiguous.
2. Customization request -> discussions-first (§6.3.2) on the relevant UIKit / SwiftUI mirror, then the wired curated docs below, then the customer-local SDK surface.
3. Hand off to the platform agent to generate the override (theme/colorset/fontset or component/slot replacement) from a verified pattern, host-correct.
4. Quick-menu the 5 most-asked tweaks; offer the advanced subclass/slot path.

## Wired knowledge (populated and cited)
- UIKit theming: `knowledge/curated/<platform>/cross-cutting/theme.md` — iOS `SBUTheme.set(colorScheme:)` + per-component themes; Android `SendbirdUIKit.setDefaultThemeMode(...)`; JS `<App theme="light|dark">` + `--sendbird-*` CSS vars; RN foundation themes.
- iOS UIKit components: `knowledge/curated/ios/products/uikit.md` — custom message cells (including file messages), input bar buttons and attachment options, disabling input, channel list item and loading indicator, header, thumbnails, video playback. iOS theme at runtime, fonts, strings: `knowledge/curated/ios/cross-cutting/theme.md`.
- iOS SwiftUI (SendbirdSwiftUI): `knowledge/curated/ios/hosts/swiftui.md` — `headerItem`/`listItem`/`inputItem` builders for message views, reply thumbnails, input buttons, channel-list search and loading, header, theme.
- UIKit component customization (JS): `knowledge/curated/js/products/uikit.md` — React render props and React Native fragment modules for message rendering (including file messages), the message input, the channel list (custom row, filter, loading state), and the channel header.

## No-Fabrication
Theme/override symbols must be verified for the host (no invented theme APIs). Uncited -> fetch the verified source or decline. Cite each symbol.
