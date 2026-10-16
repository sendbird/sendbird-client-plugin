---
name: docs-search
description: Search Sendbird official docs, public samples, and public discussions to answer a how-do-I or what-is question across any Sendbird product/platform. Use when the user asks about Sendbird documentation or concepts.
argument-hint: "[query]"
allowed-tools: WebFetch, Read, Glob, Grep, Bash, Agent
---

# /sendbird-client:docs-search

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.

The docs agent answers this question, not this session. Resolve it with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> docs` (it prints `sendbird-docs-agent`), then hand off to `sendbird-docs-agent` by calling the `Agent` tool once with the agent as Claude Code lists it, `sendbird-client:sendbird-docs-agent`. In Codex, which has no `Agent` tool, hand off by running the plugin's `sendbird-docs-agent` launcher skill instead. Do not read the knowledge files, search the docs index, fetch docs pages, or write an answer yourself before the agent responds; the lookup brief below is the agent's work.

## Steps
1. Run `route-agent.sh <project-dir> docs` and keep the agent name it prints.
2. Call `Agent` once with the agent as Claude Code lists it: this plugin's name, a colon, and the name the router printed (`sendbird-client:sendbird-docs-agent`). Claude Code lists plugin agents by that namespaced name, not by the bare name the router prints. Pass the user's query word for word, the platform and product when the question or the project names them, and the lookup brief below. This call starts the chain, so it carries no `[delegation-hop: 1]` marker; the docs agent keeps its one delegation for a code answer (`docs/AGENT_CONTRACT.md` section 5).
3. Wait for the agent result and return its answer with its citations. Do not add facts, symbols, or links the agent did not cite. When the agent says "I don't know — here's what I checked", pass that on unchanged.
4. Only if the `Agent` tool is unavailable or the call fails: say that the docs agent could not be started, then follow the lookup brief in this session under the same rules.

## Lookup brief (for the docs agent)
1. Read `config/plugin-config.json` for `docs.publicBase` and the public repo matrix.
2. Consult sources in priority order: `knowledge/curated/` (every curated doc is populated — concepts in `common/`, per-platform products/cross-cutting/hosts) → `knowledge/imports/` when present (bundled mode) → a sendbird.com/docs page found in `${CLAUDE_PLUGIN_ROOT}/core/docs-index.json` (`jq` by `product` + `platform`, or `grep -i <topic>`; WebFetch that exact `url`, never construct one) → public discussions.
3. Pricing/quota/version questions: `common/pricing-quotas.md` and `common/release-channels.md` say to NEVER quote figures or "latest" versions from memory — point to sendbird.com/pricing / the registry.
4. Return: answer + primary source citation + up to three related links (docs links only from `core/docs-index.json`).

Hard rules (No-Fabrication, see CLAUDE.md):
- Never invent an API, error code, or docs URL.
- If nothing is found, reply "I don't know — here's what I checked" and list the sources searched.
- Label any discussion-sourced answer as a community pattern, not official spec.
