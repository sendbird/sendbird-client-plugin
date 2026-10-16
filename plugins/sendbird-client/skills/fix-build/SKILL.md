---
name: fix-build
description: Fix a build or bundler error that involves a Sendbird package — Next.js server rendering, webpack 5 or Vite Node.js core module errors, Create React App, Metro or Expo, Gradle repository resolution, Android 16 KB pages, manifest merger FileProvider conflicts, and Swift Package Manager or CocoaPods. Reads the pasted log, classifies it by host, and applies the documented fix. Use when the customer pastes a build, bundler, Gradle, or Xcode error that names a Sendbird package.
argument-hint: "[pasted error or log path]"
allowed-tools: Read, Edit, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:fix-build

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating a fix.

Works from the error text the customer pasted (or a log file they point to). It does not run a build unless the customer explicitly asks for one in this request.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and resolve platform, host, package manager, and the installed Sendbird versions (lockfile, Gradle files, `Package.resolved`, `Podfile.lock`).
2. Read the error. Note the failing tool (Next.js, webpack, Vite, Create React App, Metro or Expo, Gradle, manifest merger, Xcode, SPM, CocoaPods), the first error line, and every path or package name it prints. When the message points at a file outside `node_modules/@sendbird/`, `com.sendbird.sdk`, or a Sendbird Swift package, say that another dependency causes it and stop.
3. Classify it with the table below and read only the cited section. Compare the installed version with the version the section names.
4. Report: the class, the evidence line from the log, the cause, and the fix with its citation. Apply the fix only after the customer confirms, through the platform agent; keep the project's package manager and do not add `--legacy-peer-deps`, `--force`, or `--ignore-engines` (docs/AGENT_CONTRACT.md section 3).
5. Verification: if the customer asked for a build, run their own build command once and report its result. Otherwise list the exact command for them to run and mark the build "not run".

| Class (what the log shows) | Curated section |
| --- | --- |
| Next.js: "Cannot use import statement outside a module" or "self is not defined" while rendering on the server | `knowledge/curated/js/cross-cutting/troubleshooting.md` "Next.js: ..." |
| webpack 5, Vite, or Create React App names a Node.js core module (`crypto`, `events`, `https`, ...) inside a Sendbird package; "process is not defined" from UIKit React | `knowledge/curated/js/cross-cutting/troubleshooting.md` "webpack 5, Vite, or Create React App: ..." |
| React Native: missing BottomSheet or ActionMenu context, or other errors from two copies of a Sendbird package | `knowledge/curated/js/cross-cutting/troubleshooting.md` "Errors that come from two copies of a Sendbird package"; `knowledge/curated/js/hosts/react-native.md` "Version compatibility checklist" |
| React Native: the UIKit container throws "Cannot read property 'options' of undefined", or asks for media packages | `knowledge/curated/js/cross-cutting/troubleshooting.md`, the UIKit container entry under "Build and setup" |
| Gradle cannot resolve `com.sendbird.sdk:*` | `knowledge/curated/android/cross-cutting/troubleshooting.md` "Gradle can't resolve ..."; `knowledge/curated/android/setup.md` "Packaging (Gradle)" |
| Android 15 crash on 16 KB pages, or unexpected Conscrypt `.so` files | `knowledge/curated/android/cross-cutting/troubleshooting.md` (16 KB entry); `knowledge/curated/android/setup.md` "Getting a newer Chat SDK under UIKit" |
| Manifest merger fails on a `FileProvider` (`provider@authorities` or `FILE_PROVIDER_PATHS`) | `knowledge/curated/android/cross-cutting/troubleshooting.md` "Manifest merger fails on a `FileProvider` ..." |
| Xcode: "No such module" for a Sendbird module, a package that does not resolve, or a version conflict between Sendbird packages | `knowledge/curated/ios/setup.md` "Packaging — prefer Swift Package Manager" and "Keep shared dependencies compatible"; `knowledge/curated/ios/cross-cutting/pitfalls.md` "Setup / packaging" |
| Compile errors right after moving from Chat SDK v3 to v4 or UIKit v2 to v3: old names (`SBDMain`, `SendBird.init`, `new SendBird(...)`) no longer resolve, or calls ask for a `params` argument | `knowledge/curated/<platform>/cross-cutting/migration.md`; on iOS also `knowledge/curated/ios/cross-cutting/troubleshooting.md` "Upgrading from v3" |

Rules for iOS packaging come from the plugin's policy: install with Swift Package Manager; use CocoaPods only when the project already has a `Podfile`, and never create one. `sendbird-chat-ios-spm` is the legacy v3 package; Chat v4 lives in `sendbird-chat-sdk-ios`.

When the error fits none of these rows, look for it in `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` and `pitfalls.md`, then in the docs (`${CLAUDE_PLUGIN_ROOT}/core/docs-index.json`). If no verified source covers this framework or message, say "I have no verified guidance for this build error", list what you checked, and stop. Do not write bundler configuration, polyfills, or Gradle workarounds from memory.

## Wired knowledge (populated and cited)
- `knowledge/curated/js/cross-cutting/troubleshooting.md` "Build and setup" — Next.js, webpack 5, Vite, Create React App, duplicate packages, the React Native UIKit container.
- `knowledge/curated/android/cross-cutting/troubleshooting.md` "Build and install" — Gradle repository, 16 KB pages, UIKit init, FileProvider merger.
- `knowledge/curated/<platform>/cross-cutting/migration.md` — Chat SDK v3 to v4 and UIKit v2 to v3 renames, in the order of the public migration guides.
- `knowledge/curated/<platform>/setup.md` — coordinates, repositories, and version pairing; `knowledge/curated/js/hosts/react-native.md` — React Native version checklist.

## No-Fabrication
Every cause and fix must cite one of the sections above, a published package file, or official docs. Never invent a config key, a plugin, a polyfill package, or a version number. If the installed version cannot be read, say so and ask for the lockfile line instead of assuming one.
