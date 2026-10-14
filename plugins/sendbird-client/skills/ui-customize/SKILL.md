---
name: ui-customize
description: Customize Sendbird UIKit UI — theme, colors, fonts, dark mode, navbar, message bubble, and component replacement — for the detected host. Use when the customer wants to restyle or override Sendbird UI.
argument-hint: "[--product uikit]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:ui-customize

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

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
