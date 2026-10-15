---
name: permissions-setup
description: Turn permission requirements into the right Sendbird layer — "users must not create channels", "only operators see the edit button", "freeze, mute, or ban from UIKit". Decides for each requirement whether it is an application setting, a server-side Platform API job, or client code, links the docs for the first two, and writes only the client part (operator role checks, hiding or disabling UIKit actions, moderation calls). Use when the customer describes who may do what in chat.
argument-hint: "[requirements]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:permissions-setup

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed versions. Note whether the screens are UIKit or the app's own Chat SDK code.
2. Split the request into single requirements. Put each into exactly one layer, using the rules below, and show the table to the customer before writing code.
3. Application setting: name the setting, link the official docs page (find it in `${CLAUDE_PLUGIN_ROOT}/core/docs-index.json`), and never describe dashboard click paths. If no docs page names the setting and a curated entry says Sendbird support changes it, say that.
4. Server or Platform API: say that this plugin writes client code only and does not generate server or Platform API code, name what the server must do in one sentence, and link the Platform API overview (https://sendbird.com/docs/chat/platform-api/v3/overview) or a more specific page you have opened and checked.
5. Client: write the code through the platform agent, from the curated sections below. A client check only changes what the UI offers; it is not a security boundary. Say so whenever a requirement is really about preventing an action, and pair it with the setting or server item that enforces it.
6. Before you finish, follow each screen that used a control you removed or hid, and make sure a member can still reach it the way the requirement allows. Removing the only path into a channel screen leaves the app unusable even though every rule is met.
7. Check the result by reading the project (docs/AGENT_CONTRACT.md section 4; this run does not build, contract section 3) and report each requirement as done in code, handed to settings, or handed to the server.

| Requirement | Layer | Source |
| --- | --- | --- |
| Users must not create channels from the app; channels are created by our backend | Application setting plus server: Sendbird can block channel creation from the SDK, and channels are then created through the Platform API. With the block on, client creation fails with 400108. Remove or hide create-channel UI in the client as well, and keep a way into the channels the backend creates: if the create action was the app's only way to open a channel, replace it with the current user's channel list (a channel collection or a my-channel list query) or with opening a channel by its URL, so members still reach those channels. | `knowledge/curated/ios/cross-cutting/troubleshooting.md` "Creating a channel from the app fails with 400108" (staff answer in its second case); `knowledge/curated/<platform>/products/chat.md` "Create and list group channels" |
| Only operators may freeze, mute, or ban; members see no moderation UI | Client: check the current user's role in the channel, call the moderation APIs only for operators, and hide the actions otherwise. Promoting a member to operator is a client call too. | `knowledge/curated/<platform>/products/chat.md` "Moderation (ban, mute, block, freeze)" and "Invite members and manage operators" |
| Only operators see an edit or settings button | Client: same role check, used to hide or disable the control. iOS UIKit shows the moderation row only to operators by default, and the docs show how to change the settings rows and the member list header. | `knowledge/curated/ios/products/uikit.md` "Channel settings and member list"; `knowledge/curated/<platform>/products/chat.md` "Moderation (ban, mute, block, freeze)" |
| Freeze, mute, or ban from UIKit screens | Client: UIKit's channel settings already include moderation for operators. Link the UIKit moderation docs page for the host from `core/docs-index.json` before writing custom calls. | UIKit moderation pages in `core/docs-index.json`; the community case https://community.sendbird.com/t/how-to-freeze-channel-mute-member-ban-member-via-react-ui-kit/4506 (staff pointed to the UIKit channel settings) |
| Turn off the message input for some users | Client: UIKit already disables the input for a frozen channel or a muted user; for your own rule, follow the host's input section. | `knowledge/curated/js/products/uikit.md` (React Native message input), `knowledge/curated/android/products/uikit.md` "Message input: attachment menu, extra buttons, enabled state (View host)", `knowledge/curated/android/hosts/compose.md` "Message input: attachment menu and enabled state" |
| Members must not see messages from before they joined | Application setting (chat history). | `knowledge/curated/js/cross-cutting/troubleshooting.md` "Messages sent before a user joined are missing, ..." |
| Anything about issuing tokens, creating users, or bulk moderation from an admin tool | Server or Platform API; out of scope for this plugin, which writes client code only. | https://sendbird.com/docs/chat/platform-api/v3/overview |

When a requirement fits no row, decide the layer from a cited source or say that the layer could not be verified and ask; do not assume that a setting exists.

## Wired knowledge (populated and cited)
- `knowledge/curated/<platform>/products/chat.md` "Moderation (ban, mute, block, freeze)" — operator-only actions, role check, mute and freeze state, block for any user, moderation events.
- `knowledge/curated/<platform>/products/chat.md` "Invite members and manage operators" — adding and removing operators.
- `knowledge/curated/<platform>/products/chat.md` "Create and list group channels" — listing the current user's channels, the path that replaces in-app creation.
- `knowledge/curated/<platform>/products/uikit.md` and `knowledge/curated/<platform>/hosts/*.md` — settings rows, member list header, message input enabled state.
- `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` and `errors.md` — what a blocked action returns (400108).

## No-Fabrication
Never invent an application setting, a dashboard path, a role name, or a Platform API endpoint. Name a setting only when a cited curated entry or docs page names it; otherwise say that the setting could not be verified. Generate only client code, and only with APIs from the cited sections or the installed SDK surface.
