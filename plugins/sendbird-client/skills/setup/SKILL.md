---
name: setup
description: Wizard to integrate Sendbird into the current project. Detects platform, host, package manager, lifecycle, and products; installs the SDK, inserts init + connect, and scaffolds a first screen. Use when starting a Sendbird integration or running first-time setup.
argument-hint: "[--product chat|uikit|calls]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:setup

Interactive first-integration wizard.

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

## Steps
1. Detect the project: run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` every time. Resolve platform, host, packageManager, deploymentTarget, lifecycle, products. If any Tier-1 fact is `unknown` or host is `hybrid`, ASK the customer once — never guess.
2. Resolve `app_id`: env `SENDBIRD_APP_ID` > `.sendbird-client/profile.json` (`appId` field) > ask. After the customer confirms it, **persist it** into `.sendbird-client/profile.json` (`appId`) so it is asked only once per project — App IDs are not secret. NEVER store session/access tokens anywhere (tokens stay in env at runtime).
3. Hand off to the platform agent (`sendbird-ios-agent` / `sendbird-android-agent` / `sendbird-js-agent`) for code edits.
4. The agent installs the SDK dependency, inserts initialize + connect in the correct lifecycle entry, and (optionally) scaffolds a first screen from `templates/<platform>/<host>/<product>/`.
   - iOS: install via Swift Package Manager. Use CocoaPods only if the project already has a `Podfile`; never create one or run `pod install` on a fresh/SPM project.
5. Output the edit diff + a product-specific next-step checklist; suggest `/sendbird-client:verify-integration`.

## Wired knowledge (read these FIRST — populated and cited)
- Install coordinates + packaging policy: `knowledge/curated/<platform>/setup.md` (iOS is SPM-first).
- Product init/connect/send: `knowledge/curated/<platform>/products/<product>.md` (chat/uikit/calls — all populated; iOS snippets build-verified, JS type-checked).
- Verified splice code: `templates/ios/uikit/{chat/InitConnect.swift, uikit/SetupUIKit.swift, calls/SetupCalls.swift}` and the matching `templates/android/view/...`, `templates/js/react/...`, `templates/js/react-native/...` files (each `_README.md` documents splice steps).
- Non-native hosts (SwiftUI/Compose): the host `_README.md` under templates explains the verified interop path — no host-native SDK API exists; do not invent one.

## No-Fabrication
The platform agent emits only verified API (from knowledge/curated, customer-local SDK, the public mirror, or sendbird.com/docs), citing each symbol. If a needed API can't be verified, it says "I don't know — here's what I checked" and stops. No invented SDK calls.
