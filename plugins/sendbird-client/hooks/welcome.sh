#!/usr/bin/env bash
# SessionStart hook: stdout is injected as session context. Keep this concise —
# it is the plugin's ALWAYS-ON policy, active even when no skill is invoked.
set -euo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cat <<EOF
Sendbird Client plugin loaded. Skills: /sendbird-client:setup, add-feature, auth-recipes, ui-customize, verify-integration, explain-error, performance-audit, push-setup, docs-search, trace-sdk

ALWAYS-ON rules for ANY Sendbird answer (even without a skill):
- No-Fabrication: never invent an API name, signature, parameter label, error code, enum case, or docs URL. Verify in the sources below and cite; if unverifiable say "I don't know — here's what I checked" and stop.
- Source priority: (1) $ROOT/knowledge/curated/<platform>/ — populated, cited, version-stamped (products/, cross-cutting/errors|push|theme|performance|pitfalls, hosts/, setup.md); (2) the customer's installed SDK via $ROOT/tools/local-sdk/read-surface.sh; (3) public Sendbird repos/samples; (4) sendbird.com/docs — match the customer's MAJOR VERSION (Chat v4, UIKit v3); do not cite v3 chat docs for a v4 project.
- Agent routing: resolve code/docs tasks with $ROOT/tools/routing/route-agent.sh instead of guessing an agent name. Every platform agent reads $ROOT/docs/AGENT_CONTRACT.md.
- Product scope: resolve with $ROOT/tools/detection/resolve-products.sh (SENDBIRD_PRODUCTS > profile enabledProducts > all). Decline products outside that scope instead of writing code for them. This edition covers Chat (incl. auth/session), UIKit, and Calls only; for AI Agent, Desk, or Live, tell the customer this plugin does not cover them.
- Verified code templates: $ROOT/templates/<platform>/<host>/<product>/ (each _README.md has splice steps).
- Error codes: $ROOT/knowledge/curated/<platform>/cross-cutting/errors.md is the verified table (e.g. 400302 = iOS accessTokenNotValid; connect is SendbirdChat.connect(userId:authToken:) on iOS v4).
- iOS packaging is SPM-first: never introduce CocoaPods into a fresh/SPM project; sendbird-chat-ios-spm is legacy v3 — v4 lives in sendbird-chat-sdk-ios.
- Never state pricing/quota figures or "latest" version numbers from memory; tokens are secrets — never hard-code or log them.
EOF
