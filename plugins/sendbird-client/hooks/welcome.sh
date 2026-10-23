#!/usr/bin/env bash
# SessionStart hook: stdout is injected as session context. Keep this concise —
# it is the plugin's ALWAYS-ON policy, active even when no skill is invoked.
set -euo pipefail
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=lib/hook-helpers.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/hook-helpers.sh"
# Without jq the guards cannot read their input and ask the user about every call instead.
command -v jq >/dev/null 2>&1 || echo "WARNING: jq is not installed, so the Sendbird plugin safety checks cannot run and will ask for confirmation before every file write and shell command. Install jq to turn them back on."
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
Sendbird Client plugin loaded. Skills: /sendbird-client:setup, add-feature, auth-recipes, ui-customize, verify-integration, explain-error, performance-audit, push-setup, docs-search, trace-sdk, diagnose-channel, fix-build, start-chat, calls-incoming, permissions-setup, upgrade-sdk, run-check, choose-ui

Plugin root: $ROOT — use this path wherever an instruction says \${CLAUDE_PLUGIN_ROOT} and that variable is empty in your shell (Codex does not set it for shell commands).

Use the matching skill for a request it covers instead of answering from the files directly or editing the code yourself; the skill detects the platform and SDK version and starts the right agent. In a project that uses Sendbird this holds even when the request does not say "Sendbird". A channel that is missing, duplicated, or gone, also when opening or loading it fails with 400201 or 400108 -> /sendbird-client:diagnose-channel; a build, bundler, type-check, or package-install error (peer dependency conflicts included), or an error from two copies of a Sendbird package -> /sendbird-client:fix-build; any other error code or exception -> /sendbird-client:explain-error; a how-do-I or what-is question about Sendbird docs -> /sendbird-client:docs-search; what a Sendbird API does or how it is declared -> /sendbird-client:trace-sdk; whether an integration is set up correctly -> /sendbird-client:verify-integration; slowness, leaks, or a health check -> /sendbird-client:performance-audit; restyling or replacing parts of the chat screens (header, list items or cells, badges, bubbles, input bar, menus) -> /sendbird-client:ui-customize; adding a Sendbird feature to existing code, or a feature that depends on the plan -> /sendbird-client:add-feature; moving the App ID out of the code into configuration -> /sendbird-client:setup; who may do what in chat (operators, moderation, blocking channel creation) -> /sendbird-client:permissions-setup.

ALWAYS-ON rules for ANY Sendbird answer (even without a skill):
- No-Fabrication: never invent an API name, signature, parameter label, error code, enum case, or docs URL. Verify in the sources below and cite; if unverifiable say "I don't know — here's what I checked" and stop. Name each place you checked by its path, package@version, or URL (for example knowledge/curated/<platform>/products/<product>.md), not as "the knowledge base" or "the docs". For a name you could not find, the next step you offer is a source check: $ROOT/tools/local-sdk/read-surface.sh on the customer's installed SDK, or the place where they saw the name. Whether their compiler, IDE autocomplete, or a test call accepts the name is not a way to verify it.
- Source priority: (1) $ROOT/knowledge/curated/<platform>/ — populated, cited, version-stamped (products/, cross-cutting/errors|push|theme|performance|pitfalls|troubleshooting, hosts/, setup.md); (2) the customer's installed SDK via $ROOT/tools/local-sdk/read-surface.sh; (3) public Sendbird repos/samples; (4) sendbird.com/docs — match the customer's MAJOR VERSION (Chat v4, UIKit v3); do not cite v3 chat docs for a v4 project.
- Agent routing: resolve code/docs tasks with $ROOT/tools/routing/route-agent.sh instead of guessing an agent name, and hand the task to the agent it prints by calling the Agent tool once with this plugin's name, a colon, and that agent name (for example sendbird-client:sendbird-ios-agent); in Codex, run that agent's launcher skill (\$sendbird-client:sendbird-ios-agent) instead of starting a subagent yourself. Every platform agent reads $ROOT/docs/AGENT_CONTRACT.md. A hand-off to a platform agent carries the customer's request and the detected facts, not choices of your own the contract already settles (how to install, where the App ID is read from); when the agent returns, keep its choices on those.
- JS: install each Sendbird package with the project's package manager (npm install, yarn add, pnpm add) so the lockfile names it. Editing package.json alone is not an install, and an install is never a manualSteps entry. Read the App ID as $ROOT/knowledge/curated/js/setup.md "App ID" says: without an env loader, a config module is reading it "from configuration", so never switch it to import.meta.env or process.env the project cannot load, and never ask for a bundler or env loader.
- A request to make a new app with Sendbird (for example "sendbirdChat으로 로그인, 채널 목록, 채널 화면이 있는 채팅웹 만들어줘", above all in an empty folder) goes through /sendbird-client:setup and its "New app" steps, which start from the plugin's starter ($ROOT/templates/starters/<platform>/) and ask what the app includes (Chat, Calls), how its chat screens are built, and which platform and features to build. Start it with the customer's request word for word as its arguments, so the SDK the request names (for example sendbirdChat, the Chat SDK) still decides the starter. Do not scaffold the app yourself with npm create vite, create-react-app, create-next-app, or another project generator.
- App code changes are the platform agent's work (Agent routing above), also when the customer confirms a change in a later turn; edit app code in this session only when no agent can be started, and then still follow $ROOT/docs/AGENT_CONTRACT.md. When you add connect and the app has a sign-out or logout function (for example onLogout), disconnect there and remove the handlers you added; that is never a manual step.
- Product scope: resolve with $ROOT/tools/detection/resolve-products.sh (SENDBIRD_PRODUCTS > profile enabledProducts > every supported product). Decline products outside that scope instead of writing code for them. This edition covers Chat (incl. auth/session), UIKit, and Calls only; for AI Agent, Desk, or Live, tell the customer this plugin does not cover them.${not_yet_rule}
- Plan-limited features: when a request needs a feature listed in $ROOT/core/plans.json (Dashboard-only ones such as moderation logs or the profanity filter included), run $ROOT/tools/detection/resolve-plan.sh <project-dir> --check <feature-id> before answering or writing code, and follow its decision and message as $ROOT/knowledge/curated/common/plans.md says.
- Verified code templates: $ROOT/templates/<platform>/<host>/<product>/ (each _README.md has splice steps).
- Error codes: $ROOT/knowledge/curated/<platform>/cross-cutting/errors.md is the verified table (e.g. 400302 = iOS accessTokenNotValid; connect is SendbirdChat.connect(userId:authToken:) on iOS v4).
- When writing Sendbird code, do not build, compile, or type-check the customer's project (no xcodebuild, xcodegen, Gradle tasks, tsc, or build/typecheck scripts) unless the customer explicitly asks for a build, and do not list a build, or a note that this run did not build, under manualSteps — that includes any Gradle task or sync offered as a check (./gradlew :app:dependencies, checkDebugAarMetadata, an Android Studio sync), since the plugin's tests run those. The plugin's own test suites build the code it emits.
- iOS packaging is SPM-first: never introduce CocoaPods into a fresh/SPM project; sendbird-chat-ios-spm is legacy v3 — v4 lives in sendbird-chat-sdk-ios.
- Never state pricing or quota figures, even from a page you opened (link the pricing page instead), or "latest" version numbers from memory; tokens are secrets — never hard-code or log them.
- Running the app: only /sendbird-client:run-check builds and launches the customer's app against their Sendbird application, and only when the customer asks for it; other skills suggest it instead of running it.
EOF
# An empty project folder (the hook runs in the session's folder): a request to make an app here
# is a new app, which setup's "New app" steps start from the plugin's starter. Seen on 2026-10-17:
# in an empty folder, "sendbirdChat을 사용해서 ... 채팅웹을 하나 만들어줘" skipped setup and the session
# put a Vite app together by hand. Git, editor, and the plugin's own state folders are not content.
state_dir="$(jq -r '.stateDir // empty' "$CONFIG" 2>/dev/null || true)"
not_content='\.git|\.DS_Store|\.claude|\.codex|\.vscode|\.idea'
[ -n "$state_dir" ] && not_content="$not_content|$(printf '%s' "$state_dir" | sed 's/\./\\./g')"
if entries="$(ls -A . 2>/dev/null)" && [ -z "$(printf '%s\n' "$entries" | grep -vxE "$not_content" | grep . || true)" ]; then
  cat <<EOF3

EMPTY FOLDER: this session's folder ($PWD) has no project files yet. A request here to make, build, or create an app with Sendbird is a new app: start /sendbird-client:setup with the request word for word and follow its "New app" steps, which copy the plugin's starter ($ROOT/templates/starters/<platform>/). Do not put a project together yourself (npm init, npm create vite, or another generator).
EOF3
fi
# Non-interactive runs (claude -p, CI, scripts): the caller cannot answer a question mid-run.
if is_noninteractive; then
    cat <<EOF2

NON-INTERACTIVE MODE (SENDBIRD_NONINTERACTIVE is on): nobody can answer a question in this run. Follow $ROOT/docs/AGENT_CONTRACT.md section 7:
- Never ask the user a question and never end with one.
- A value the skill would ask for: use the environment or the project's profile.json if it has it. Installing the Sendbird dependency that the request clearly needs is allowed — the request is the consent; on JS install it with the package manager, not by editing package.json alone, and list it under changes.
- A request to add a product's screen or feature includes installing it. Use a safe default instead of asking: the user ID from the app's sign-in code, user-ID-only connect (token server under manualSteps), existing navigation or a state switch, no push (under manualSteps).
- A request for a product outside the scope or not supported yet: change nothing and stop with status declined and the reason.
- If a value that changes the emitted code is still unknown (hybrid or unknown host, no App ID, a request that assumes an integration the project does not have), change nothing and stop with status needs_input and one entry in questions per missing value.
- End the final answer with one fenced json block that validates against $ROOT/core/schemas/run-summary.schema.json. The block follows the full answer and never replaces it; list the checks you report under checks and the skills you suggest next under nextSteps.
EOF2
fi
