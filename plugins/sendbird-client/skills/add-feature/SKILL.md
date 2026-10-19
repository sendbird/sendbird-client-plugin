---
name: add-feature
description: Add a Sendbird feature to the project (channel, message, reaction, thread, typing, file, push, call, and more). Use when the customer wants to add a specific Sendbird capability to existing code.
argument-hint: "<feature> [--product <product>]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:add-feature

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

Add one feature to an existing integration.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, product, and installed SDK versions. If an ambiguity changes the emitted code, ask one focused question.
2. Check the plan: if the feature is listed in `core/plans.json`, run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-plan.sh" <project-dir> --check <feature-id>` and follow `knowledge/curated/common/plans.md` before any file is changed. On `confirm`, show the message and build only after the customer says yes; on `sales`, show the message and write no code. In a non-interactive run, the request answers with `confirm-<feature-id>=yes` (build it) or `confirm-<feature-id>=no` (leave it out); without that answer, change nothing and return `status: "needs_input"` with one question: id `confirm-<feature-id>`, the decision's `message` as `question`, options `["yes", "no"]`.
3. This is a customization request: consult sources discussions-first per §6.3.2 (public discussions on the relevant UIKit mirror), then knowledge/curated (populated — see below), then the customer-local SDK / public source / docs.
4. Hand off to the platform agent to splice the matching template under `templates/<platform>/<host>/<product>/` and wire imports/delegates/hooks.
5. Output the edit + a per-feature validation checklist + Related docs.

## Wired knowledge (populated and cited)
- Plan-limited features: `knowledge/curated/common/plans.md` (data in `core/plans.json`).
- Per-product API: `knowledge/curated/<platform>/products/<product>.md` — channel/message (chat), prebuilt screens (uikit), dial (calls).
- Verified base templates exist for every product on ios/uikit, android/view, js/react, js/react-native (each dir's `_README.md` has splice steps + variations).
- Chat message features have templates on all six hosts, under `templates/<platform>/<host>/chat/` (the `_README.md` there has per-feature splice steps):

  | Feature | ios/uikit, android/view | ios/swiftui | android/compose | js/react, js/react-native |
  |---|---|---|---|---|
  | Send an image or file, upload progress, cancel, resend a failed one | `FileMessageSender` | `FileUploadModel` | `FileUploadViewModel` | `FileMessageUpload.ts` (no upload progress on React Native) |
  | Edit and delete your own messages, other members' edits and deletes | `MessageEditing` | `MessageActionsModel` | `MessageActionsViewModel` | `MessageEditing.ts` |
  | Unread counts (total badge, per channel, mark as read) | `UnreadCount` | `UnreadCountModel` | `UnreadCountViewModel` | `UnreadCount.ts` |
  | Typing indicator and read receipts | `TypingAndReadReceipts` | `ChannelActivityModel` | `ChannelActivityViewModel` | `TypingAndReadReceipts.ts` |

- Calls (a voice or video call, accept or decline an incoming call, sign out of Calls): `templates/<platform>/<host>/calls/` on all six hosts; the folder's `_README.md` has the permissions and splice steps, and `templates/js/react/calls/DirectCallPanel.tsx` is a ready call screen for React. On iOS, Android, and React Native, incoming calls need push even while the app is open (the `calls-incoming` skill; a `manualSteps` entry for the dashboard credentials); dialing out does not.
- If the specific feature isn't templated yet, derive it from the curated doc's cited sections or the customer-local SDK surface — never from memory.

## No-Fabrication
Every API in the inserted code must be verified and cited. If the feature/template is not yet verified for this platform+host, say so and offer the verified docs link rather than inventing code. Discussions are community signal, labeled as such.
