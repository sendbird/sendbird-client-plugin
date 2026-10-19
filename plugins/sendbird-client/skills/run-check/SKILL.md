---
name: run-check
description: Build and launch the project's app against the customer's own Sendbird application and check that it really works — sign-in, connect, a channel a second test user opens, and messages both ways — with screenshots. Runs only when the customer asks for it and agrees to the build. Use when the customer wants to confirm that the integration works for real.
argument-hint: "[--host react|ios-uikit|ios-swiftui|android-view|android-compose]"
allowed-tools: Read, Bash, Grep, Glob, Agent, AskUserQuestion
---

# /sendbird-client:run-check

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
For a question about the project's sign-in or connect code, resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`.

Runs the app for real. This is the only skill that builds and launches the customer's project, and it does so only because the customer asked.

## When to run
- Only when the customer asked to run or check the app for real (this command, or a request such as "check that it really works"). Never start it from another skill or as a verification step of setup, add-feature, or upgrade-sdk; those suggest it instead.
- Supported hosts are the ones the runtime harness supports: React web (`react`), iOS UIKit and SwiftUI apps built from an XcodeGen `project.yml` (`ios-uikit`, `ios-swiftui`), and Android View and Compose apps with a Kotlin-DSL `app/build.gradle.kts` (`android-view`, `android-compose`). For React Native, Flutter, Unity, .NET, Unreal, a hybrid project, or anything else, say the run check does not support that project yet and stop.

## Steps
1. **Host.** Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and map platform and host to a harness host (js/react → `react`; ios uikit or swiftui → `ios-uikit` or `ios-swiftui`; android view or compose → `android-view` or `android-compose`). Anything else is not supported (see above).
2. **Sign-in without tokens.** The check signs in two new test users with a user ID only. Read the project's Sendbird connect call (the platform's `knowledge/curated/<platform>/products/auth.md` shows the forms). If the app passes an access or session token, or gets one from its own server before connecting, report that the run check cannot sign in to an app that requires tokens and stop. The Sendbird application itself must also allow connecting with a user ID only; when it does not, the run fails at `connect` with an error code (step 6).
3. **Preflight.** Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/runtime/run.sh" <project-dir> --host <host> --check`. It copies, installs, and builds nothing, and prints JSON: `appId.from` (where the App ID comes from: `SENDBIRD_APP_ID` or the project's `profile.json`; the value is never printed), `appIdHow`, `signIn`, the `checks` it will run, `missing`, and `notes` (what it will install and build). When `ready` is false, report each `missing` entry and what would fix it, and stop:
   - no App ID: the customer sets `SENDBIRD_APP_ID` or confirms the App ID with `/sendbird-client:setup` (stored as `appId` in `.sendbird-client/profile.json`);
   - a tool not found (Xcode, XcodeGen, a JDK or Android SDK, an emulator image, Node): name it; do not install it;
   - no sign-in hook: the harness signs in through the app's `onLoginSucceeded(userId)` (the sign-in hook the setup skill fills) or a starter's sign-in form; without one there is nothing it can drive.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): when the App ID is the only `missing` entry, stop with `status: "needs_input"` and one question, id `app-id`, asking for it through `SENDBIRD_APP_ID`. Any other `missing` entry ends the run with `status: "failed"` and `reason` naming each entry. Nothing is run in either case.
4. **Go-ahead.** Tell the customer, from the preflight `notes`, what will happen: the project is copied to a temporary folder and never changed; the listed tools are installed outside the project; the app is built and launched (browser, simulator, or emulator; iOS and Android builds take several minutes); two test users with generated IDs (`rt-<host>-a-…`, `rt-<host>-b-…`) sign in to the customer's application, open a channel, and send messages, which stay in that application. Ask once whether to go ahead.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): go ahead only when the request itself says to build and launch or run the check (for example "you have my go-ahead to build and launch it"). Otherwise run nothing and stop with `status: "needs_input"` and one question, id `run-check-go-ahead`, options `yes` and `no`.
5. **Run.** `bash "${CLAUDE_PLUGIN_ROOT}/tools/runtime/run.sh" <project-dir> --host <host> --out <project-dir>/.sendbird-client/run-check/<UTC time, e.g. 20261014T101500Z>` with a Bash timeout of at least 10 minutes. The tool reads the App ID itself; never pass it on the command line, echo it, or write it anywhere. Exit codes: 0 pass, 1 fail, 2 skipped (a tool or device was missing), 64 bad arguments.
6. **Report** from `<out>/runtime.json`:
   - a table of every step with pass, fail, or not run and its detail: `sign-in`, `chat-screen`, `connect`, `channel`, `message-a-receives`, `message-a-sends`, then `message-b-screen` (React) or `message-a-live` (iOS, Android), `errors`. A step with `ok: null` did not apply (an app without UIKit screens checks `connect` only); report it as not run, never as passed;
   - the test user IDs (`users.a`, `users.b`), the results folder, and the screenshots folder `<out>/screens/`;
   - on a failure: the first failed step, its detail, and the log file in `<out>` that has more. A connect failure that names an error code: look the code up in `knowledge/curated/<platform>/cross-cutting/errors.md` and cite it. Do not paste raw logs; they are stored with the App ID removed, but quote only the lines you need.
   In a non-interactive run, end with the run summary (`core/schemas/run-summary.schema.json`, `skill: "run-check"`): `completed` when every check passed, `failed` with the first failed step as `reason`, `declined` for an unsupported project or an app that requires tokens. `changes` is empty: the results folder belongs to the plugin, not to the app.

## Wired knowledge
- Harness: `tools/runtime/run.sh` (and `--check`), `tools/runtime/lib/appid.py` (how the App ID reaches the copy: an environment variable, a build setting, a Gradle property, a placeholder in a config file, or the App ID the config already holds when it matches), `tools/runtime/lib/peer.mjs` (user B).
- Connect forms and tokens: `knowledge/curated/<platform>/products/auth.md`. Error codes: `knowledge/curated/<platform>/cross-cutting/errors.md`.

## No-Fabrication
Report only what `runtime.json` and the logs show; never describe a skipped or not-run step as passed, and never guess why a step failed beyond what the detail and logs say — cite the error code table when a code appears. If the reason is not in the output, say "I don't know — here's what I checked" and name the files you read.
