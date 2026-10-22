---
name: auth-recipes
description: Generate correct Sendbird connection/session code — direct connect, session-token issue/refresh, multi-device, reauth, safe logout — for the detected platform/host. Auth is part of Chat. Use when the customer asks about authentication, session tokens, or login/logout flows.
argument-hint: "<flow: session-token|jwt|multi-device|reauth|logout>"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:auth-recipes

Connection/session flows (a Chat capability).

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed (out of the configured scope, or not supported yet) and that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; a non-interactive run ends with `status: "declined"`.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>`, then inspect the customer code and installed SDK surface for direct-connect or session-token handling. Ask once if the code does not establish the current auth posture.
2. Read `knowledge/curated/<platform>/products/auth.md` for the requested flow and the session-expiry codes in `knowledge/curated/<platform>/cross-cutting/errors.md` before handing off. Then hand off to the platform agent to produce the verified pattern (session delegate/handler, token refresh, safe disconnect) from the wired sources below, passing the sections and codes you read.
3. Note Dashboard config requirements (link docs, don't invent paths).

## Wired knowledge (populated and cited)
- Flows + symbols: `knowledge/curated/<platform>/products/auth.md` — session-token connect, refresh (`SessionDelegate` iOS / `SessionHandler` Android+JS, registered BEFORE connect), reauth, multi-device, logout. Pinned and latest templates compile or type-check on all three platforms.
- Templates: `templates/ios/uikit/auth/SessionAuth.swift`, `templates/android/view/auth/SessionAuth.kt`, `templates/js/react/auth/session.ts`, `templates/js/react-native/auth/session.ts`.
- Session-expiry error codes: per-platform `knowledge/curated/<platform>/cross-cutting/errors.md` (e.g. 400309/400310).

## No-Fabrication
Session-delegate/handler symbols + token APIs must be verified + cited. Never invent an auth API. Unverified -> "I don't know — here's what I checked".
