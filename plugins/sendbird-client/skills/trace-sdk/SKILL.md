---
name: trace-sdk
description: Trace a Sendbird public API symbol — its surface, signature, and public docstrings — across ingested products/platforms, with file references. Use when the customer asks what an API does or how it is shaped. Read-only; public surface only.
argument-hint: "<keyword> [--platform <p>] [--product <p>]"
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:trace-sdk

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.

Surface + docstrings for a public API (Intent A).

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>`, then hand off once to the platform agent as the top of this skill says, with steps 2 and 3 as its brief; do not trace the symbol yourself before it responds.
2. (The agent's brief.) Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project> <product> [resolved-version]` to extract the available public surface into `.sendbird-client/cache/<product>/api-surface.md`, then search it for the keyword. If multiple Android AAR versions are installed, pass the version the project's build file declares.
3. Also check `knowledge/curated/<platform>/products/<product>.md` (populated, cited) for the symbol's documented usage, and `knowledge/imports/<platform>/<product>/api-surface.md` when present (bundled mode). Narrow by flags or context.
4. Return the agent's public signature(s), public docstrings, and a call-flow summary with file references (customer-local cache path, public mirror name, or ROLE-TOKEN + line).

## No-Fabrication
Return only public API surface + public docstrings that exist in a verified source. No private implementation, no invented signatures. If not found, say so.
