#!/usr/bin/env bash
# SessionStart hook: stdout is injected as session context. Keep this concise —
# it is the plugin's ALWAYS-ON policy, active even when no skill is invoked.
set -euo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cat <<EOF
Sendbird Client plugin loaded. Skills: /sendbird-client:setup, add-feature, auth-recipes, ui-customize, verify-integration, explain-error, performance-audit, push-setup, docs-search, trace-sdk

ALWAYS-ON rules for ANY Sendbird answer (even without a skill):
- No-Fabrication: never invent an API name, signature, parameter label, error code, enum case, or docs URL. Verify in the sources below and cite; if unverifiable say "I don't know — here's what I checked" and stop. Name each place you checked by its path, package@version, or URL (for example knowledge/curated/<platform>/products/<product>.md), not as "the knowledge base" or "the docs".
- Source priority: (1) $ROOT/knowledge/curated/<platform>/ — populated, cited, version-stamped (products/, cross-cutting/errors|push|theme|performance|pitfalls|troubleshooting, hosts/, setup.md); (2) the customer's installed SDK via $ROOT/tools/local-sdk/read-surface.sh; (3) public Sendbird repos/samples; (4) sendbird.com/docs — match the customer's MAJOR VERSION (Chat v4, UIKit v3); do not cite v3 chat docs for a v4 project.
- Agent routing: resolve code/docs tasks with $ROOT/tools/routing/route-agent.sh instead of guessing an agent name. Every platform agent reads $ROOT/docs/AGENT_CONTRACT.md.
- Editing app code without an agent still follows $ROOT/docs/AGENT_CONTRACT.md. When you add connect and the app has a sign-out or logout function (for example onLogout), disconnect there and remove the handlers you added; that is never a manual step.
- Product scope: resolve with $ROOT/tools/detection/resolve-products.sh (SENDBIRD_PRODUCTS > profile enabledProducts > all). Decline products outside that scope instead of writing code for them. This edition covers Chat (incl. auth/session), UIKit, and Calls only; for AI Agent, Desk, or Live, tell the customer this plugin does not cover them.
- Verified code templates: $ROOT/templates/<platform>/<host>/<product>/ (each _README.md has splice steps).
- Error codes: $ROOT/knowledge/curated/<platform>/cross-cutting/errors.md is the verified table (e.g. 400302 = iOS accessTokenNotValid; connect is SendbirdChat.connect(userId:authToken:) on iOS v4).
- iOS packaging is SPM-first: never introduce CocoaPods into a fresh/SPM project; sendbird-chat-ios-spm is legacy v3 — v4 lives in sendbird-chat-sdk-ios.
- Never state pricing/quota figures or "latest" version numbers from memory; tokens are secrets — never hard-code or log them.
EOF
# Non-interactive runs (claude -p, CI, scripts): the caller cannot answer a question mid-run.
case "${SENDBIRD_NONINTERACTIVE:-}" in
  1|true|TRUE|yes)
    cat <<EOF2

NON-INTERACTIVE MODE (SENDBIRD_NONINTERACTIVE is set): nobody can answer a question in this run. Follow $ROOT/docs/AGENT_CONTRACT.md section 7:
- Never ask the user a question and never end with one.
- A value the skill would ask for: use the environment or the project's profile.json if it has it. Adding the Sendbird dependency that the request clearly needs is allowed — the request is the consent; list it under changes.
- A request to add a product's screen or feature includes installing it. Use a safe default instead of asking: the user ID from the app's sign-in code, user-ID-only connect (token server under manualSteps), existing navigation or a state switch, no push (under manualSteps).
- If a value that changes the emitted code is still unknown (hybrid or unknown host, no App ID, a request that assumes an integration the project does not have), change nothing and stop with status needs_input and one entry in questions per missing value.
- End the final answer with one fenced json block that validates against $ROOT/core/schemas/run-summary.schema.json.
EOF2
    ;;
esac
