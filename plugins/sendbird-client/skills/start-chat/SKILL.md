---
name: start-chat
description: Add a "Chat with seller" style button that opens a 1:1 Sendbird chat directly — find or create the distinct 1:1 channel with the other user's ID, open the UIKit channel screen by its URL without the channel list, fit the app's navigation, and optionally open the same channel from a push tap. Use when the customer wants a button, profile action, or deep link that starts a conversation with a specific user.
argument-hint: "[other-user-id source] [--push]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:start-chat

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed (out of the configured scope, or not supported yet) and that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; a non-interactive run ends with `status: "declined"`. This skill needs Chat and UIKit.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed versions. If UIKit is not installed, set it up first with the `setup` skill's flow, then continue.
2. Find in the project: the screen and control that should start the chat, where the other user's ID comes from (a seller model, a route parameter, a profile object), the app's navigation (UINavigationController or a SwiftUI `NavigationStack`, Android activities or Navigation Compose, react-router, React Navigation), the code that already initializes and connects Sendbird and the connection state it keeps (a session status, a connected flag, the result of its connect call), and any push handler that already reads the Sendbird payload (the `sendbird` key): an Android Firebase messaging service or Sendbird push handler subclass, an iOS notification center delegate, or a React Native messaging handler. The detector's `tier2.pushProvider` is only a hint; the handler in the code is the evidence. Ask one question only when the other user's ID has no source in the code; in a non-interactive run follow docs/AGENT_CONTRACT.md section 7. Steps 3 to 5 are the platform agent's brief: hand them over in step 6 and do not make these edits yourself.
3. Find or create the channel: create a group channel with only the other user's ID and `isDistinct` set to true. With distinct on, the server returns the existing channel that has the same members instead of creating a second one. Do not query for an existing channel first and do not create a non-distinct channel. Create only after connect has completed (`products/chat.md` "Call APIs only after connect completes"): disable the control until the connection state from step 2 says connected, or check that state before creating. An error alert after a failed create does not replace this check.
4. Open the channel screen by the URL of the returned channel, with no channel list in between, using the host's section below. Keep the app's navigation: push onto the existing stack or route, so the back action returns to the screen that had the button.
5. Push tap (only when asked, or when step 2 found a handler that already reads the Sendbird payload): read the channel URL from the Sendbird payload and open the same screen. Use only the host sections below; where a host has no verified section, say so and leave push out. Put a `source:` comment naming the push.md section in the file that handles the tap.
   Change only what a tap opens. Do not change push registration: token registration, entitlements, background modes, the `google-services` Gradle plugin, Firebase initialization, or the notification permission. When registration is missing, leave it and add a `manualSteps` entry to run the `push-setup` skill. Install no push package either: when the tap needs a library the app does not have yet (for example Notifee on React Native Android), leave that part out and name it in the same `manualSteps` entry.
6. Hand the splice to the platform agent once, with the host section and the files and lines from step 2. Check the result by reading the project (docs/AGENT_CONTRACT.md section 4; this run does not build, contract section 3).
7. Report, whether the agent or you made the change: the step 2 findings with file:line (the screen and control, the source of the other user's ID, the navigation, the existing initialize and connect code), the changed files, and a table with one row per check below plus the section 4 checks, each pass, fail, or not run with file:line. In a non-interactive run, put the same rows under the run summary's `checks`.
   - `distinct-create`: one create call, with only the other user's ID and `isDistinct` true, and no channel query before it
   - `after-connect`: the create call runs only after connect has completed
   - `open-by-url`: the channel screen opens by the returned channel's URL, with no channel list in between
   - `back-returns`: the screen is pushed onto the existing stack or route, so back returns to the screen with the button
   - `no-new-navigation`: no navigation library was added
   - `host-section`: the host section from the table below that the code follows, cited
   - `push-tap`: done, or left out with the reason
   - `build`: not run (this run does not build)

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
