---
name: performance-audit
description: Scan a Sendbird integration for known anti-patterns — repeated connects, handler/listener leaks, eager pagination, unoptimized images, missing offline cache, and product-specific pitfalls. Use when the customer reports slowness, memory growth, or wants a health check.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:performance-audit

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.

Scan for known anti-patterns (read-first; fixes confirmed).

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed SDK versions.
2. Hand the inspection to the platform agent once, as the top of this skill says, with step 3 as its brief, and wait for its result. Do not read the sources yourself instead, even in a small project.
3. (The agent's brief.) Grep the project for the verified anti-patterns from `knowledge/curated/<platform>/cross-cutting/performance.md` + `pitfalls.md` (both populated): repeated init/connect, handler-leak pairs (iOS `addChannelDelegate` without `removeChannelDelegate`; Android `addChannelHandler` without `removeChannelHandler`; JS `addGroupChannelHandler` without `removeGroupChannelHandler` in effect cleanup), eager pagination without a `limit`, local caching disabled (`isLocalCachingEnabled`/`useCaching`), unoptimized images, plus product pitfalls from `products/<product>.md`.
4. Report each finding from the agent's result with severity + file:line + a cited fix suggestion (apply via the platform agent on confirm).
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): apply only when the request itself asks for the fix; otherwise change nothing and stop with `needs_input` and the `apply-fix` question (docs/AGENT_CONTRACT.md section 7).

## No-Fabrication
Anti-patterns + fixes come from curated/verified sources, cited. Don't invent a "best practice" — if a pitfall isn't in a verified source, don't assert it.
