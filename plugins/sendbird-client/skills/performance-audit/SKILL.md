---
name: performance-audit
description: Scan a Sendbird integration for known anti-patterns — repeated connects, handler/listener leaks, eager pagination, unoptimized images, missing offline cache, and product-specific pitfalls. Use when the customer reports slowness, memory growth, or wants a health check.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:performance-audit

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.

Scan for known anti-patterns (read-first; fixes confirmed).

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed SDK versions.
2. Delegate the platform-specific inspection once to the detected platform agent.
3. Grep the project for the verified anti-patterns from `knowledge/curated/<platform>/cross-cutting/performance.md` + `pitfalls.md` (both populated): repeated init/connect, handler-leak pairs (iOS `addChannelDelegate` without `removeChannelDelegate`; Android `addChannelHandler` without `removeChannelHandler`; JS `addGroupChannelHandler` without `removeGroupChannelHandler` in effect cleanup), eager pagination without a `limit`, local caching disabled (`isLocalCachingEnabled`/`useCaching`), unoptimized images, plus product pitfalls from `products/<product>.md`.
4. Report each finding with severity + file:line + a cited fix suggestion (apply via the platform agent on confirm).

## No-Fabrication
Anti-patterns + fixes come from curated/verified sources, cited. Don't invent a "best practice" — if a pitfall isn't in a verified source, don't assert it.
