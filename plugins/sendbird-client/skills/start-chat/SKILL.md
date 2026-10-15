---
name: start-chat
description: Add a "Chat with seller" style button that opens a 1:1 Sendbird chat directly — find or create the distinct 1:1 channel with the other user's ID, open the UIKit channel screen by its URL without the channel list, fit the app's navigation, and optionally open the same channel from a push tap. Use when the customer wants a button, profile action, or deep link that starts a conversation with a specific user.
argument-hint: "[other-user-id source] [--push]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:start-chat

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products. This skill needs Chat and UIKit.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed versions. If UIKit is not installed, set it up first with the `setup` skill's flow, then continue.
2. Find in the project: the screen and control that should start the chat, where the other user's ID comes from (a seller model, a route parameter, a profile object), the app's navigation (UINavigationController or a SwiftUI `NavigationStack`, Android activities or Navigation Compose, react-router, React Navigation), and the code that already initializes and connects Sendbird. Ask one question only when the other user's ID has no source in the code; in a non-interactive run follow docs/AGENT_CONTRACT.md section 7.
3. Find or create the channel: create a group channel with only the other user's ID and `isDistinct` set to true. With distinct on, the server returns the existing channel that has the same members instead of creating a second one. Do not query for an existing channel first and do not create a non-distinct channel. Create only after connect has completed (`products/chat.md` "Call APIs only after connect completes").
4. Open the channel screen by the URL of the returned channel, with no channel list in between, using the host's section below. Keep the app's navigation: push onto the existing stack or route, so the back action returns to the screen that had the button.
5. Push tap (only when asked, or when the app already handles Sendbird push): read the channel URL from the Sendbird payload and open the same screen. Use only the host sections below; where a host has no verified section, say so and leave push out.
6. Hand the splice to the platform agent once, with the host section and the files and lines from step 2. Check the result by reading the project (docs/AGENT_CONTRACT.md section 4; this run does not build, contract section 3) and report each check as pass, fail, or not run.

| Host | Open a channel by URL (and push tap) |
| --- | --- |
| iOS UIKit | `knowledge/curated/ios/products/uikit.md` "Start a 1:1 chat from a button (no channel list)": push the channel view controller for the URL; from a push tap, `moveToChannel(channelURL:basedOnChannelList: false)`. Payload: `knowledge/curated/ios/cross-cutting/push.md` "Handle a notification payload (background and tap)". |
| iOS SwiftUI | `knowledge/curated/ios/hosts/swiftui.md` "Start a 1:1 chat from a button (SendbirdSwiftUI)"; the template `templates/ios/swiftui/uikit` (`SendbirdChannelScreen`). No verified SwiftUI push-tap section: leave push out and say so. |
| Android View | `knowledge/curated/android/products/uikit.md` "Start a 1:1 chat from a button (no channel list)", including the push-tap `PendingIntent`. |
| Android Compose | `knowledge/curated/android/hosts/compose.md` "Start a 1:1 chat from a button (Compose UIKit)"; the template `templates/android/compose/uikit` (`openSendbirdChannel`). |
| React | `knowledge/curated/js/products/uikit.md` "Start a 1:1 chat from a button (no channel list)" under React. No verified browser push-tap guide: leave push out and say so. |
| React Native | `knowledge/curated/js/products/uikit.md` "Start a 1:1 chat from a button (no channel list)" under React Native; push tap from `knowledge/curated/js/cross-cutting/push.md` "React Native: opening a channel from a push tap". |

## Wired knowledge (populated and cited)
- Distinct 1:1 creation: `knowledge/curated/<platform>/products/chat.md` "Create and list group channels"; why channels duplicate without it: `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` (duplicate 1:1 channel entries).
- Opening a channel and navigation: the host sections in the table above, and `templates/<platform>/<host>/uikit/` (each `_README.md` has splice steps).
- Push payload and tap handling: `knowledge/curated/<platform>/cross-cutting/push.md`; push registration itself belongs to the `push-setup` skill.

## No-Fabrication
Every API in the inserted code must come from the cited sections, a template, or the installed SDK surface. Navigation code uses only the app's existing navigation library and Apple, Android, or React APIs; never an invented Sendbird navigation helper. If a host has no verified way to open a channel from a push tap, say so instead of writing one.
