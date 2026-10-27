---
name: verify-integration
description: Sanity-check a Sendbird integration — dependency/version, single init, required permissions/manifest, handler add/remove pairing, and common misuse — per platform and product. Use when the customer asks whether their setup is correct or something is not working.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:verify-integration

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md. A shell command that only reads or checks files exits 0 when a file it looks for is missing (`if [ -f <file> ]; then cat <file>; fi`, or `|| true` after an optional read), and quotes separator lines (`echo '=== name'`: zsh, the default macOS shell, treats a word that starts with `=` as a command name). Otherwise a normal check is shown to the customer as a failed command.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`, then hand off to that agent (for example `sendbird-android-agent`) by calling the `Agent` tool once with that agent as Claude Code lists it (this plugin's name, a colon, then the agent name). In Codex, which has no `Agent` tool, hand off by running the plugin's launcher skill with that agent's name instead (for example the `sendbird-android-agent` skill). Do not perform the platform checklist yourself or return an integration verdict before the agent responds. If the hand-off fails, report that the platform inspection was not completed; a router result alone is not an inspection.

Read-only sanity scan (Intent A — factual checks). It reads the project and does not build, compile, or type-check it unless the customer explicitly asks for a build.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, products, and installed SDK versions.
2. Run `route-agent.sh` for the same project and immediately hand off to the agent it prints, once (Claude Code: the `Agent` tool; Codex: that agent's launcher skill). Pass the detected facts and ask the agent to inspect each detected product for dependency presence and supported version, single initialization in the right lifecycle, required permissions/manifest keys, event-handler add/remove (or unsubscribe) pairing, and common misuses. Require file and line evidence for every verdict.
3. Wait for the agent result. If a required check has no evidence, mark it not verified instead of completing it from memory or a related document.
4. Report pass / warn / fail / not verified per check, with the file:line evidence. Every check gets its own line with its own file:line, passing checks included; never group passing checks into one line. Name the fix for each finding (it is applied only in a later request that asks for it). In a non-interactive run, put the same rows under the run summary's `checks` (`not_verified` for not verified). This skill is read-only, so a run whose request does not ask for the fix ends with `status: "completed"`: list each offered fix under `nextSteps` and add no `apply-fix` or other question (`docs/AGENT_CONTRACT.md` section 7).

## Wired knowledge (populated and cited — source of checklist expectations)
- Coordinates + versions: `knowledge/curated/<platform>/setup.md` (compare against the project's lockfile/Gradle/SPM, warn on drift from `last-verified-against`).
- Correct init/lifecycle per product: `knowledge/curated/<platform>/products/<product>.md`.
- Handler pairing + misuse list: `knowledge/curated/<platform>/cross-cutting/performance.md` and `pitfalls.md` (e.g. `addChannelDelegate`/`removeChannelDelegate`, `addChannelHandler`/`removeChannelHandler`, `addGroupChannelHandler`/`removeGroupChannelHandler`).
- Auth posture: `knowledge/curated/<platform>/products/auth.md` (session handler registered before connect).

## No-Fabrication
Checks reference only verified expectations (cited to knowledge/curated or docs). If the correct version/permission for a product can't be verified, mark that check "unknown — verify against docs" rather than asserting a value.
