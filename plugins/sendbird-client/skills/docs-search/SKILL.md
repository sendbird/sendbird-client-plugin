---
name: docs-search
description: Search Sendbird official docs, public samples, and public discussions to answer a how-do-I or what-is question across any Sendbird product/platform. Use when the user asks about Sendbird documentation or concepts.
argument-hint: "[query]"
allowed-tools: WebFetch, Read, Glob, Grep, Bash, Agent
---

# /sendbird-client:docs-search

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the docs agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> docs` before delegating.

Delegate to `sendbird-docs-agent` to answer the user's query.

Steps:
1. Read `config/plugin-config.json` for `docs.publicBase` and the public repo matrix.
2. Consult sources in priority order: `knowledge/curated/` (all 57 docs populated — concepts in `common/`, per-platform products/cross-cutting/hosts) → `knowledge/imports/` when present (bundled mode) → a sendbird.com/docs page found in `${CLAUDE_PLUGIN_ROOT}/core/docs-index.json` (`jq` by `product` + `platform`, or `grep -i <topic>`; WebFetch that exact `url`, never construct one) → public discussions.
3. Pricing/quota/version questions: `common/pricing-quotas.md` and `common/release-channels.md` say to NEVER quote figures or "latest" versions from memory — point to sendbird.com/pricing / the registry.
4. Return: answer + primary source citation + up to three related links (docs links only from `core/docs-index.json`).

Hard rules (No-Fabrication, see CLAUDE.md):
- Never invent an API, error code, or docs URL.
- If nothing is found, reply "I don't know — here's what I checked" and list the sources searched.
- Label any discussion-sourced answer as a community pattern, not official spec.
