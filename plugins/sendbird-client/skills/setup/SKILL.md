---
name: setup
description: Wizard to integrate Sendbird into the current project. Detects platform, host, package manager, lifecycle, and products; installs the SDK, inserts init + connect, and scaffolds a first screen. Use when starting a Sendbird integration or running first-time setup.
argument-hint: "[new-app] [--product chat|uikit|calls]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent, AskUserQuestion
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

## New app (empty folder)
Use this when the request is to create a new app, or the project folder is empty (detection finds no platform).

1. Read the questions from `${CLAUDE_PLUGIN_ROOT}/core/catalog.json`. Drop options whose `product` is outside the active scope (`resolve-products.sh`), and drop a question with no options left. Skip a question whose `when` does not match the answers so far.
2. Get the answers:
   - Interactive: ask with AskUserQuestion, using the catalog's question text and option labels as written (translated into the customer's language if needed). Use `multiSelect` for `multi` questions. Ask `platform` first, then the rest together (at most 4 questions per call). Do not add, drop, or reword options.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): read answers from the request, written as `answers: platform=react; chat=channel-list,conversation; calls=voice-call; notes=...`. An answer that is not a catalog option id is an error. If the request has no answers yet, change nothing and stop with `status: "needs_input"`, returning every catalog question in scope at once, in catalog order, each with its `id`, `question`, `type`, option ids as `options`, the option labels as `labels` (same order), and `when` when it has one, so the caller can ask them all and run again once (with `--resume` it continues this session). If answers are given but a `required` question that applies is missing, return only the missing ones the same way. When `SENDBIRD_LOCALE` is set (a language such as `ko` or `ja`), write `question` and `labels` in that language; never translate `id`, `options`, or `when`, since the caller passes answers back by option id.
3. Copy the starter named by `starters` in the catalog (`platform`, or `platform/<ios-ui|android-ui>`) from `${CLAUDE_PLUGIN_ROOT}/` into the project folder, then initialize git if the folder is not a repository.
4. Continue with Steps 2–5 above: App ID, then the platform agent implements sign-in and connect in the starter's `onLoginSucceeded` and `onLogout`, then every chosen feature, and shows each on screen. Install packages and build or type-check as the agent contract requires.
5. Write the run summary (`core/schemas/run-summary.schema.json`, with `skill: "setup"`) to the path in `SENDBIRD_RUN_SUMMARY_FILE` when it is set, in both modes, so the caller can read the result after the session ends. List the answers used under `steps`.

## Wired knowledge (read these FIRST — populated and cited)
- Install coordinates + packaging policy: `knowledge/curated/<platform>/setup.md` (iOS is SPM-first).
- Product init/connect/send: `knowledge/curated/<platform>/products/<product>.md` (chat/uikit/calls — all populated; iOS snippets build-verified, JS type-checked).
- Verified splice code: `templates/ios/uikit/{chat/InitConnect.swift, uikit/SetupUIKit.swift, calls/SetupCalls.swift}` and the matching `templates/android/view/...`, `templates/js/react/...`, `templates/js/react-native/...` files (each `_README.md` documents splice steps).
- Non-native hosts (SwiftUI/Compose): the host `_README.md` under templates explains the verified interop path — no host-native SDK API exists; do not invent one.

## No-Fabrication
The platform agent emits only verified API (from knowledge/curated, customer-local SDK, the public mirror, or sendbird.com/docs), citing each symbol. If a needed API can't be verified, it says "I don't know — here's what I checked" and stops. No invented SDK calls.
