---
name: auth-recipes
description: Generate correct Sendbird connection/session code — direct connect, session-token issue/refresh, multi-device, reauth, safe logout — for the detected platform/host. Auth is part of Chat. Use when the customer asks about authentication, session tokens, or login/logout flows.
argument-hint: "<flow: session-token|jwt|multi-device|reauth|logout>"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:auth-recipes

Connection/session flows (a Chat capability).

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>`, then inspect the customer code and installed SDK surface for direct-connect or session-token handling. Ask once if the code does not establish the current auth posture.
2. For the requested flow, hand off to the platform agent to produce the verified pattern (session delegate/handler, token refresh, safe disconnect) from the wired sources below.
3. Note Dashboard config requirements (link docs, don't invent paths).

## Wired knowledge (populated and cited)
- Flows + symbols: `knowledge/curated/<platform>/products/auth.md` — session-token connect, refresh (`SessionDelegate` iOS / `SessionHandler` Android+JS, registered BEFORE connect), reauth, multi-device, logout. Pinned and latest templates compile or type-check on all three platforms.
- Templates: `templates/ios/uikit/auth/SessionAuth.swift`, `templates/android/view/auth/SessionAuth.kt`, `templates/js/react/auth/session.ts`, `templates/js/react-native/auth/session.ts`.
- Session-expiry error codes: per-platform `knowledge/curated/<platform>/cross-cutting/errors.md` (e.g. 400309/400310).

## No-Fabrication
Session-delegate/handler symbols + token APIs must be verified + cited. Never invent an auth API. Unverified -> "I don't know — here's what I checked".
