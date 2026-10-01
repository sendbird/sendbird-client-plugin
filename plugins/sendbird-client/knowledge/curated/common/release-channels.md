<!-- last-verified-against: n/a (conceptual) -->
<!-- status: populated -->
# common — release channels

> Conceptual cross-platform guidance (no specific version numbers asserted; check the repos for current versions). Verified 2026-06-10.

## Where releases live
- iOS: SPM packages / GitHub releases on the public mirrors (e.g. `sendbird-chat-sdk-ios`, `sendbird-uikit-ios-spm`).
- Android: Maven at `repo.sendbird.com/public/maven`.
- JS: npm (`@sendbird/chat`, `@sendbird/uikit-react`, `@sendbird/live`, `sendbird-calls`, `sendbird-desk`, etc.).

## Versioning
- SDKs follow semantic versioning. Pin to a major (e.g. Chat v4, UIKit v3) and take minor/patch updates.
- AI Agent requires minimum Chat + UIKit versions — check the AI Agent quickstart for the current floor (see products/ai-agent.md).
- The `sendbird-chat-ios-spm` mirror is legacy v3; v4 lives in `sendbird-chat-sdk-ios`.

## What the plugin should do
- Read the customer's installed version from their lockfile/SDK and ground answers in it; warn if it differs from the curated `last-verified-against` version. Don't assert a "latest" version number from memory — resolve it from the registry/repo.

## Related
- Setup: per-platform setup.md
- Architecture: per-platform architecture.md
