---
name: verify-integration
description: Sanity-check a Sendbird integration — dependency/version, single init, required permissions/manifest, handler add/remove pairing, and common misuse — per platform and product. Use when the customer asks whether their setup is correct or something is not working.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:verify-integration

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`, then call `Agent` with that exact agent name. Do not perform the platform checklist yourself or return an integration verdict before the agent responds. If `Agent` is unavailable or fails, report that the platform inspection was not completed; a router result alone is not an inspection.

Read-only sanity scan (Intent A — factual checks). It reads the project and does not build, compile, or type-check it unless the customer explicitly asks for a build.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed SDK versions.
2. Run `route-agent.sh` for the same project and immediately call `Agent` once. Pass the detected facts and ask the agent to inspect each detected product for dependency presence and supported version, single initialization in the right lifecycle, required permissions/manifest keys, event-handler add/remove (or unsubscribe) pairing, and common misuses. Require file and line evidence for every verdict.
3. Wait for the agent result. If a required check has no evidence, mark it not verified instead of completing it from memory or a related document.
4. Report pass / warn / fail / not verified per check, with the file:line evidence. Offer an auto-fix per finding (customer confirms).

## Wired knowledge (populated and cited — source of checklist expectations)
- Coordinates + versions: `knowledge/curated/<platform>/setup.md` (compare against the project's lockfile/Gradle/SPM, warn on drift from `last-verified-against`).
- Correct init/lifecycle per product: `knowledge/curated/<platform>/products/<product>.md`.
- Handler pairing + misuse list: `knowledge/curated/<platform>/cross-cutting/performance.md` and `pitfalls.md` (e.g. `addChannelDelegate`/`removeChannelDelegate`, `addChannelHandler`/`removeChannelHandler`, `addGroupChannelHandler`/`removeGroupChannelHandler`).
- Auth posture: `knowledge/curated/<platform>/products/auth.md` (session handler registered before connect).

## No-Fabrication
Checks reference only verified expectations (cited to knowledge/curated or docs). If the correct version/permission for a product can't be verified, mark that check "unknown — verify against docs" rather than asserting a value.
