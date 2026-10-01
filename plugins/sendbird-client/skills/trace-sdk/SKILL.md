---
name: trace-sdk
description: Trace a Sendbird public API symbol — its surface, signature, and public docstrings — across ingested products/platforms, with file references. Use when the customer asks what an API does or how it is shaped. Read-only; public surface only.
argument-hint: "<keyword> [--platform <p>] [--product <p>]"
allowed-tools: Read, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:trace-sdk

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.

Surface + docstrings for a public API (Intent A).

## Steps
1. Detect the platform and delegate once to its platform agent. In runtime-fetch mode, run `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project> <product> [resolved-version]` to extract the available public surface into `.sendbird-client/cache/<product>/api-surface.md`, then search it for the keyword. If multiple Android AAR versions are installed, pass the version resolved by the customer build.
2. Also check `knowledge/curated/<platform>/products/<product>.md` (populated, cited) for the symbol's documented usage, and `knowledge/imports/<platform>/<product>/api-surface.md` when present (bundled mode). Narrow by flags or context.
3. Return the public signature(s), public docstrings, and a call-flow summary with file references (customer-local cache path, public mirror name, or ROLE-TOKEN + line).

## No-Fabrication
Return only public API surface + public docstrings that exist in a verified source. No private implementation, no invented signatures. If not found, say so.
