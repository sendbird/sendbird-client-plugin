---
name: add-feature
description: Add a Sendbird feature to the project (channel, message, reaction, thread, typing, file, push, and more). Use when the customer wants to add a specific Sendbird capability to existing code.
argument-hint: "<feature> [--product <product>]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:add-feature

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

Add one feature to an existing integration.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, product, and installed SDK versions. If an ambiguity changes the emitted code, ask one focused question.
2. This is a customization request: consult sources discussions-first per §6.3.2 (public discussions on the relevant UIKit mirror), then knowledge/curated (populated — see below), then the customer-local SDK / public source / docs.
3. Hand off to the platform agent to splice the matching template under `templates/<platform>/<host>/<product>/` and wire imports/delegates/hooks.
4. Output the edit + a per-feature validation checklist + Related docs.

## Wired knowledge (populated and cited)
- Per-product API: `knowledge/curated/<platform>/products/<product>.md` — channel/message (chat), prebuilt screens (uikit).
- Verified base templates exist for every product on ios/uikit, android/view, js/react, js/react-native (each dir's `_README.md` has splice steps + variations).
- If the specific feature isn't templated yet, derive it from the curated doc's cited sections or the customer-local SDK surface — never from memory.

## No-Fabrication
Every API in the inserted code must be verified and cited. If the feature/template is not yet verified for this platform+host, say so and offer the verified docs link rather than inventing code. Discussions are community signal, labeled as such.
