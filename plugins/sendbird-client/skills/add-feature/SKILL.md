---
name: add-feature
description: Add a Sendbird feature to the project (channel, message, reaction, thread, typing, file, push, call, and more). Use when the customer wants to add a specific Sendbird capability to existing code, including a feature that depends on the Sendbird plan (listed in core/plans.json, Dashboard-only ones such as moderation logs or the profanity filter too), so the plan is checked first.
argument-hint: "<feature> [--product <product>]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:add-feature

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed (out of the configured scope, or not supported yet) and that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; a non-interactive run ends with `status: "declined"`.

Add one feature to an existing integration.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, product, and installed SDK versions. If an ambiguity changes the emitted code, ask one focused question.
2. Check the plan: if the feature is listed in `core/plans.json`, run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-plan.sh" <project-dir> --check <feature-id>` and follow `knowledge/curated/common/plans.md` before any file is changed. On `confirm`, show the message and build only after the customer says yes; on `sales`, show the message and write no code. In a non-interactive run, the request answers with `confirm-<feature-id>=yes` (build it) or `confirm-<feature-id>=no` (leave it out); without that answer, change nothing and return `status: "needs_input"` with one question: id `confirm-<feature-id>`, the decision's `message` as `question`, options `["yes", "no"]`. When the plan is `unsure` and the customer names their plan (for example in the answer to the confirmation), store it with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-plan.sh" <project-dir> --save <plan>`, so later checks use it and the plan is asked only once.
3. This is a customization request: consult knowledge/curated (populated — see below), then public discussions on the relevant UIKit mirror with `bash "${CLAUDE_PLUGIN_ROOT}/core/commands/search-discussions.sh" <owner/repo> <English keywords>` (the repository from `config/plugin-config.json` `.repos`), then the customer-local SDK / public source / docs. Label what a discussion says as community signal; when the command prints `NOT RUN: <reason>`, say in the answer that discussions were not searched and why.
4. Hand off to the platform agent to splice the matching template under `templates/<platform>/<host>/<product>/` and wire imports/delegates/hooks.
5. Report as `docs/AGENT_CONTRACT.md` section 6 lists, whether the agent or you made the change: the task envelope, the changed files, each section 4 check and each check of this feature (for example handler removal on the screen that adds it) as pass, fail, or not run with file:line, and the symbol, source, source version, and verification method table. Cite the source that contains each symbol, not a related docs page. Suggest `/sendbird-client:run-check` once (suggest only). In a non-interactive run, end with the run summary (`skill: "add-feature"`, the checks under `checks`).

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

- Calls (a voice or video call, accept or decline an incoming call, sign out of Calls): `templates/<platform>/<host>/calls/` on all six hosts; the folder's `_README.md` has the permissions and splice steps, and `templates/js/react/calls/DirectCallPanel.tsx` is a ready call screen for React. On iOS, Android, and React Native, incoming calls need push even while the app is open; dialing out does not. When this run does not wire that push, `manualSteps` lists the push credentials and names the `calls-incoming` skill as the next step (`knowledge/curated/<platform>/products/calls.md` "Manual steps").
- If the specific feature isn't templated yet, derive it from the curated doc's cited sections or the customer-local SDK surface — never from memory.

## No-Fabrication
Every API in the inserted code must be verified and cited. If the feature/template is not yet verified for this platform+host, say so and offer the verified docs link rather than inventing code. Discussions are community signal, labeled as such.
