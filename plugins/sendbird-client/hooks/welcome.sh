#!/usr/bin/env bash
# SessionStart hook: stdout is injected as session context. Keep this concise —
# it is the plugin's ALWAYS-ON policy, active even when no skill is invoked.
set -euo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Products this release does not support yet (config .productScope.notYetSupported). The rule is
# built from the config so that removing a product there is the whole change that turns it back on.
CONFIG="$ROOT/config/plugin-config.json"
if command -v jq >/dev/null 2>&1; then
  not_yet="$(jq -r '.productScope.notYetSupported[]? // empty' "$CONFIG" 2>/dev/null || true)"
else
  not_yet="$(sed -n '/"notYetSupported"/,/]/p' "$CONFIG" 2>/dev/null | grep -o '"[a-z-]*"' | tr -d '"' | grep -vx notYetSupported || true)"
fi
not_yet_rule=""
for p in $not_yet; do
  case "$p" in
    calls) label="Sendbird Calls (voice and video calls)" ;;
    *) label="$p" ;;
  esac
  not_yet_rule="$not_yet_rule
- Not supported yet: $label. When asked for it, say it is not supported yet in this plugin and do not write, fix, or set up its code, even on a direct request; in a non-interactive run, change nothing and end with status declined."
done
cat <<EOF
Sendbird Client plugin loaded. Skills: /sendbird-client:setup, add-feature, auth-recipes, ui-customize, verify-integration, explain-error, performance-audit, push-setup, docs-search, trace-sdk, diagnose-channel, fix-build, start-chat, calls-incoming, permissions-setup

Plugin root: $ROOT — use this path wherever an instruction says \${CLAUDE_PLUGIN_ROOT} and that variable is empty in your shell (Codex does not set it for shell commands).

ALWAYS-ON rules for ANY Sendbird answer (even without a skill):
- No-Fabrication: never invent an API name, signature, parameter label, error code, enum case, or docs URL. Verify in the sources below and cite; if unverifiable say "I don't know — here's what I checked" and stop. Name each place you checked by its path, package@version, or URL (for example knowledge/curated/<platform>/products/<product>.md), not as "the knowledge base" or "the docs".
- Source priority: (1) $ROOT/knowledge/curated/<platform>/ — populated, cited, version-stamped (products/, cross-cutting/errors|push|theme|performance|pitfalls|troubleshooting, hosts/, setup.md); (2) the customer's installed SDK via $ROOT/tools/local-sdk/read-surface.sh; (3) public Sendbird repos/samples; (4) sendbird.com/docs — match the customer's MAJOR VERSION (Chat v4, UIKit v3); do not cite v3 chat docs for a v4 project.
- Agent routing: resolve code/docs tasks with $ROOT/tools/routing/route-agent.sh instead of guessing an agent name. Every platform agent reads $ROOT/docs/AGENT_CONTRACT.md.
- Editing app code without an agent still follows $ROOT/docs/AGENT_CONTRACT.md. When you add connect and the app has a sign-out or logout function (for example onLogout), disconnect there and remove the handlers you added; that is never a manual step.
- Product scope: resolve with $ROOT/tools/detection/resolve-products.sh (SENDBIRD_PRODUCTS > profile enabledProducts > every supported product). Decline products outside that scope instead of writing code for them. This edition covers Chat (incl. auth/session) and UIKit only; for AI Agent, Desk, or Live, tell the customer this plugin does not cover them.${not_yet_rule}
- Verified code templates: $ROOT/templates/<platform>/<host>/<product>/ (each _README.md has splice steps).
- Error codes: $ROOT/knowledge/curated/<platform>/cross-cutting/errors.md is the verified table (e.g. 400302 = iOS accessTokenNotValid; connect is SendbirdChat.connect(userId:authToken:) on iOS v4).
- When writing Sendbird code, do not build, compile, or type-check the customer's project (no xcodebuild, xcodegen, Gradle tasks, tsc, or build/typecheck scripts) unless the customer explicitly asks for a build, and do not list a build under manualSteps. The plugin's own test suites build the code it emits.
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
- A request for a product outside the scope or not supported yet: change nothing and stop with status declined and the reason.
- If a value that changes the emitted code is still unknown (hybrid or unknown host, no App ID, a request that assumes an integration the project does not have), change nothing and stop with status needs_input and one entry in questions per missing value.
- End the final answer with one fenced json block that validates against $ROOT/core/schemas/run-summary.schema.json.
EOF2
    ;;
esac
