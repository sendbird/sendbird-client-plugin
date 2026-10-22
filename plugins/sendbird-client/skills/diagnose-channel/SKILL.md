---
name: diagnose-channel
description: Diagnose a Sendbird channel that misbehaves — a channel created by API or dashboard does not show in the list, every "message" tap creates a new 1:1 channel with the same user, a channel disappeared after members left or fetching it fails with 400201, or a user shown in the channel gets 400108. Reads the customer's code, names the cause with file:line, and offers the fix. Use when a channel is missing, duplicated, or gone, also when opening or loading it fails with 400201 or 400108.
argument-hint: "[symptom]"
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:diagnose-channel

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.

Read-first diagnosis. The skill finds the cause in the customer's code; it changes code only after the customer confirms, through the platform agent.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed SDK versions. Note whether the screens are UIKit (prebuilt list and create-channel screens) or the app's own Chat SDK code.
2. Match the symptom to one row below. Read every curated section that row names, the troubleshooting entry and the `products/chat.md` sections alike, before searching the project, and nothing else. The troubleshooting section is "Channels" on iOS, "Messages and channels" on Android, and "Channel list and channel creation" on JS, all in `knowledge/curated/<platform>/cross-cutting/troubleshooting.md`.
3. Walk that row's checks in order. For each check, search the project and record either the evidence (file:line and the code) or "not found". Stop at the first check that explains the symptom, but finish the row when evidence is ambiguous.
4. Report: the symptom; each check you walked, with its evidence and verdict (cause / ruled out / not verifiable from code); each check after the one that explained the symptom as one line, "not checked: stopped at the cause"; the cause with file:line; and the fix from the curated entry with its citation. Do not add causes from checks you did not walk. Offer the fix; on confirmation, delegate once to the platform agent with the file:line and the cited fix.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): apply only when the request itself asks for the fix; otherwise change nothing and stop with `needs_input` and the `apply-fix` question (docs/AGENT_CONTRACT.md section 7).

| Symptom | Checks, in order | Curated source |
| --- | --- | --- |
| A channel created through the Platform API, the dashboard, or another client is missing from the list | (a) The list query leaves out empty channels: find the query or UIKit list the screen uses and check whether the "include empty" option of the detected platform is set to true. UIKit's default list leaves it off. (b) A filter on that query that the channel does not pass, such as a name filter ("Filter the channel list by name"). Compare it with the channel the customer describes; verify any other filter name against the installed SDK with `tools/local-sdk/read-surface.sh` before naming it. (c) The current user is not a joined member: the "my channels" query lists only channels the user belongs to, and a channel the user has not joined needs the public channel query (JS chat.md "Create and list group channels"). (d) After `resetMyHistory()` the channel is empty again for that user (JS entry). | troubleshooting entry about channels created elsewhere; `products/chat.md` "Create and list group channels" and "Filter the channel list by name" |
| Starting a chat with the same person creates a new channel each time | (a) The create call or UIKit create-channel screen does not set `isDistinct` to true; on iOS UIKit, `isDistinct` is reset to false before your builder runs, so set it in the global create-params builder. (b) The params also mark the channel public; JS notes that a public channel cannot be distinct. | troubleshooting entry about duplicate 1:1 channels; `products/chat.md` "Create and list group channels" |
| A channel disappeared after everyone left, or fetching it fails with 400201 | (a) The app stores channel URLs and later opens one whose members all left. By default the server deletes a group channel when its member count reaches zero. No client change keeps it; the curated fix is to ask Sendbird support to change the application setting. (b) The URL is wrong (Android 400201 entry). | iOS "A group channel disappears after every member leaves"; Android 400201 entry |
| A user who appears in the channel gets 400108 "User must be a member" | (a) The user was invited but has not joined: check for code that reads the member state and accepts the invitation, or turns on automatic acceptance (JS entry). (b) The user reached the joined-channel limit (`knowledge/curated/js/cross-cutting/pitfalls.md` "Joined-channel limit"). (c) On iOS, 400108 from channel creation means the application blocks channel creation from clients (iOS entry). | JS 400108 entry; iOS "Creating a channel from the app fails with 400108"; `cross-cutting/errors.md` |
| Members don't see messages sent before they joined | Chat history is an application setting, not an SDK option, and applies only to users who join after it is turned on. Nothing in the code fixes it; link the dashboard docs instead of describing click paths. | JS "Messages sent before a user joined are missing" |

When a row's curated entry exists only for another platform, use it as a lead, not as the answer: confirm the same option on the detected platform in `knowledge/curated/<platform>/products/chat.md`, its UIKit doc, or the installed SDK surface (`bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project> chat`), and say which source confirmed it.

## Wired knowledge (populated and cited)
- `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` — symptom, cause, fix, and public cases for each row above.
- `knowledge/curated/<platform>/products/chat.md` — channel creation with `isDistinct`, channel list queries and collections, the name filter, invitations and operators.
- `knowledge/curated/<platform>/products/uikit.md` and `knowledge/curated/<platform>/hosts/*.md` — passing a custom list query to the UIKit list on each host.
- `knowledge/curated/<platform>/cross-cutting/errors.md` — 400108, 400201, and the other codes a channel call can return.

## No-Fabrication
Every cause and fix must come from a cited curated entry or the installed SDK surface. Do not invent a filter name, a default value, or a dashboard path. When the code shows nothing that explains the symptom, say which checks were ruled out with what evidence, name the application-level settings that remain (chat history, deletion of empty channels, client channel creation), and point to the docs instead of guessing.
