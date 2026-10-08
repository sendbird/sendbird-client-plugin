---
name: explain-error
description: Explain a Sendbird error code or message — its meaning, common triggers, and a fix — across any product/platform, citing the verified error table. Use when the customer hits a Sendbird error code or exception.
argument-hint: "<code-or-message>"
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:explain-error

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` when code inspection or a fix is required.

Detect the customer's platform and installed SDK version before interpreting a numeric code. Never carry a symbol or description from one platform's error enum to another platform.

Map an error to meaning + fix (Intent A — lookup).

## Steps
1. Look up the code in the verified table `knowledge/curated/<platform>/cross-cutting/errors.md`. Interpret it only with the detected platform and resolved SDK version because the same number can map to a different symbol or description on another platform.
2. For triggers and fixes, and for a symptom with no code ("push never arrives", "channel missing from the list"), check `knowledge/curated/<platform>/cross-cutting/troubleshooting.md`: symptom, cause, and fix from solved public cases, each fix re-checked against the pinned SDK. Entries marked community were resolved by users, not Sendbird staff; say so when you use one.
3. If the code isn't in the curated table: check `${CLAUDE_PLUGIN_ROOT}/knowledge/imports/<platform>/<product>/error-codes.md` when present, else read the customer-local SDK error enum via `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project> <product> [resolved-version]`, else search version-matched official docs.
4. Report: code, platform symbol (e.g. 400302 = iOS `accessTokenNotValid` / JS `SESSION_TOKEN_EXPIRED`), meaning, common triggers, fix (codegen handed to the platform agent for in-scope products), related docs link — all cited. Session-expiry codes route to `products/auth.md` refresh patterns.

## No-Fabrication
Only report error codes/meanings present in a verified source. If the code isn't found, say "not found in <searched sources>" and suggest the docs — never invent a meaning.
