---
name: upgrade-sdk
description: Upgrade the Sendbird SDKs a project already uses to the newest release of the same major version. Reads the installed versions, looks up the newest published version in the registry, lists the deprecated APIs the project calls with the replacement the SDK names, and applies the version bump and the replacements only after the customer confirms. Use when the customer asks to update or upgrade their Sendbird SDKs.
argument-hint: "[product] [--apply]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent, AskUserQuestion
---

# /sendbird-client:upgrade-sdk

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and leave out products outside it.

Upgrade within a major version: read first, change files only after the customer says yes.

## Steps
1. **Installed versions.** Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>`. For each Sendbird package the project declares, record the declared version and the resolved one:
   - JS: `package.json` and the lockfile (`package-lock.json`, `yarn.lock`, or `pnpm-lock.yaml`). Package names: `knowledge/curated/js/setup.md` "Packages (npm)".
   - iOS: `Package.resolved` (or `project.yml` / the Xcode project's package references; `Podfile.lock` only when the project already uses CocoaPods). Package URLs: `knowledge/curated/ios/setup.md`.
   - Android: `app/build.gradle(.kts)` and `gradle/libs.versions.toml` when present. Coordinates and repositories: `knowledge/curated/android/setup.md`.
   If the project has no Sendbird package, say so and suggest `/sendbird-client:setup` instead.
2. **Newest published version.** For each package run `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/latest-version.sh" <npm|spm|maven> <package> --major <installed major>` (`spm` takes the package's GitHub URL; `maven` takes the artifact, plus `--repo <url>` when `settings.gradle` declares a repository other than the default). Quote `latestInMajor`, `latest`, and `source` from its output. Never state a version from memory; if the lookup fails, report the error for that package and leave it out of the plan.
3. **Major versions are out of scope.** When `latest` is a newer major than the installed one (for example Chat v3 to v4), say that a newer major exists, that moving to it is a migration this skill does not perform, and point to the migration guide on sendbird.com/docs for that SDK. Continue with `latestInMajor` only. When `latestInMajor` equals the installed version for every package, say the project is already on the newest release of its major version and stop.
4. **Platform rules for the target versions.** First read `knowledge/curated/<platform>/setup.md`, `knowledge/curated/<platform>/hosts/<host>.md`, and, when UIKit is installed, `knowledge/curated/<platform>/products/uikit.md`. Cite each rule you apply:
   - Android: UIKit pins the Chat SDK it was built with, and an explicit newer Chat SDK declaration in the app module overrides it (`knowledge/curated/android/setup.md` "Getting a newer Chat SDK under UIKit"). When UIKit moves, read the Chat version the target UIKit POM declares (`<repo>/com/sendbird/sdk/uikit/<version>/uikit-<version>.pom`) and keep any explicit Chat declaration at or above it.
   - JS: read what the target UIKit package declares for `@sendbird/chat` with `npm view <uikit package>@<target> dependencies peerDependencies`. React Native UIKit declares it as a peer dependency, so the app installs a matching `@sendbird/chat` itself (`knowledge/curated/js/hosts/react-native.md` "Version compatibility checklist"). Keep the app's own `@sendbird/chat` inside that range so one copy is installed. Never pass `--legacy-peer-deps` or `--force` (`docs/AGENT_CONTRACT.md` section 3).
   - iOS: Swift Package Manager resolves one version of `sendbird-chat-sdk-ios` for the whole app, so the Chat version must satisfy the minimum every Sendbird package declares (`knowledge/curated/ios/setup.md`, the shared-dependency table). Read the target UIKit `Package.swift` for its Chat minimum.
5. **Deprecated APIs the project calls.** For each installed product run `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/deprecated-usage.sh" <project-dir> <product> [installed version]`. Android: run it again with the target version and `--download` to see what the target release deprecates. Each `DEPRECATED:` line gives the file, line, and the SDK's own deprecation text; the replacement is the API that text names. A line marked `(overloaded: check the call)` is a deprecated overload: open the call and keep it only when its arguments match the deprecated declaration. If the tool prints `NOT RUN: <reason>`, report the check as not run with that reason; never present it as "no deprecated APIs". If the SDK text names no replacement, say so instead of choosing one.
6. **Plan and confirmation.** Show one plan: a table of package, installed, target, and the registry source; the deprecated uses as `file:line → replacement`; the files that will change. Ask the customer once whether to apply it.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): apply only when the request itself says to apply the upgrade (for example "apply", "go ahead", "update the files", or `--apply`). Otherwise change nothing and stop with `status: "needs_input"` and one question, id `apply-upgrade`, options `yes` and `no`, whose text names each package's installed and target version.
7. **Apply (after a yes).** Call `Agent` once with the agent `route-agent.sh` returned, passing the plan:
   - bump each version with the project's package manager and its existing pin style (exact stays exact, a range stays a range), and update the lockfile (`npm install <package>@<version>` and the like);
   - replace each deprecated call with the replacement, verified in the target version's surface: `bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project-dir> <product> <target version>` after the install. A replacement whose return type or callback shape differs (for example a promise versus a request handler) is adapted at the call site without changing the signature of the app's own function;
   - run `deprecated-usage.sh` again with the target version and report what remains.
   This skill does not build the project. To build and launch it against the customer's application, suggest `/sendbird-client:run-check`.
8. **Report.** The version table (before, after, source), changed files, each deprecated call and its replacement with the citation, checks not run with the reason, and any newer major left out. In a non-interactive run, end with the run summary (`core/schemas/run-summary.schema.json`, `skill: "upgrade-sdk"`).

## Wired knowledge
- Package names, coordinates, repositories: `knowledge/curated/<platform>/setup.md`.
- Android Chat under UIKit: `knowledge/curated/android/setup.md` "Getting a newer Chat SDK under UIKit".
- JS UIKit and Chat versions: `knowledge/curated/js/products/uikit.md`, `knowledge/curated/js/hosts/react-native.md` "Version compatibility checklist".
- iOS shared-dependency minimums: `knowledge/curated/ios/setup.md`.
- Tools: `tools/local-sdk/latest-version.sh` (registry lookup), `tools/local-sdk/deprecated-usage.sh` (deprecated calls, read from the SDK files; JS uses the TypeScript language service, iOS the installed `.swiftinterface`, Android the AAR), `tools/local-sdk/read-surface.sh` (target surface).

## No-Fabrication
Every version comes from the registry output of this run, cited with its source. Every replacement API comes from the SDK's own deprecation text or the target version's surface, cited; never invent a replacement or a migration step. If a fact cannot be verified, say "I don't know — here's what I checked" and leave that change out.
