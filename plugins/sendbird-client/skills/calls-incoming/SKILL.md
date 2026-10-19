---
name: calls-incoming
description: Make Sendbird Calls ring (on iOS, Android, and React Native new incoming calls arrive only through push, even while the app is open, and also in the background or after the app was closed), and fix common in-call audio and video problems — iOS PushKit with CallKit, Android FCM with a call notification, React Native native push, and web media and WebSocket checks. Use when an app that already uses Sendbird Calls misses incoming calls, crashes on a VoIP push, or has no audio or video during a call.
argument-hint: "[symptom]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:calls-incoming

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and run `resolve-products.sh <project-dir> --check calls`. If Calls is outside the scope, say so and stop.

This skill works on an app that already uses Sendbird Calls. When the project has no Calls SDK, say so and point to `/sendbird-client:setup --product calls` (or `/sendbird-client:add-feature call`), which install it, instead of installing it here.

On iOS, Android, and React Native, new incoming calls arrive only through push, also while the app is open: the iOS and Android Authentication docs ("WebSocket") say the SDK connects its WebSocket only during a call, and an app without push never rings (seen on the iOS simulator and an Android emulator). So "calls never ring" on these platforms is a missing push setup even when the app is in the foreground.

## Steps
1. Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` and confirm the Calls SDK and its version: the iOS Swift package `sendbird-calls-ios`, `com.sendbird.sdk:sendbird-calls` on Android, `sendbird-calls` on the web, `@sendbird/calls-react-native` on React Native (source: knowledge/curated/ios/products/calls.md). Without it, stop as described above.
2. Map the current wiring with file:line evidence: where the SDK is configured or initialized, where the user authenticates, where the incoming-call listener or delegate is added, and whether push is wired (VoIP token, FCM token, push forwarding, the incoming-call UI).
3. Compare it with the platform checklist below and list each item as present, missing, or wrong, with evidence.
4. Report the gaps and the fix for each, cited. On confirmation, hand the changes to the platform agent once. Steps that need the dashboard (VoIP or FCM credentials), signing capabilities, or a real device are hand-off steps with the docs link; never describe dashboard click paths.
5. Check the result by reading the project (docs/AGENT_CONTRACT.md section 4; this run does not build, contract section 3). Incoming calls in the background need a real device and a second caller, so report that check as not run unless the customer ran it.

| Platform | Checklist (curated section) |
| --- | --- |
| iOS | `knowledge/curated/ios/products/calls.md` "Receive calls in the background or after the app was closed (PushKit + CallKit)": VoIP background mode, PushKit registry, token registered after authenticate, every VoIP push forwarded to the SDK, each ringing call reported to CallKit, answer and end through CallKit actions, audio session handed to the SDK. The crash "app terminated when a VoIP push arrives" is in `knowledge/curated/ios/cross-cutting/troubleshooting.md` "Calls". |
| Android | `knowledge/curated/android/products/calls.md` "Receive calls in the background or after the app was closed (FCM)": init and listener in `Application.onCreate`, FCM token registered after authenticate (the non-deprecated overload), FCM data forwarded to the SDK, and a call notification from the app's own foreground service. `knowledge/curated/android/cross-cutting/troubleshooting.md` "Calls" covers `onRinging` never firing and runtime microphone and camera permissions. |
| React Native | `knowledge/curated/js/cross-cutting/troubleshooting.md` "React Native: incoming calls don't ring, ..." and `knowledge/curated/js/products/calls.md` "React Native". |
| Web | `knowledge/curated/js/cross-cutting/troubleshooting.md` "Web: no remote audio or video, or incoming calls are missed" and `knowledge/curated/js/products/calls.md` "Web": the web SDK receives calls only while its WebSocket is connected; there is no push-based incoming call on the web. |

In-call audio or video problems: check the platform's troubleshooting "Calls" entries first (Android runtime permissions; web media access; the iOS audio session handed over from CallKit). For a symptom none of them covers, search `${CLAUDE_PLUGIN_ROOT}/core/docs-index.json` for the Calls docs page and cite it, or say that no verified source covers it.

On Android, apply the `com.google.gms.google-services` Gradle plugin only when `app/google-services.json` exists, and never create a placeholder file; an unconditional apply fails the build when the file is missing. When the file is absent, the customer downloads it from their Firebase project into `app/`, and that is a hand-off step (`knowledge/curated/android/products/calls.md` "Manual steps").

On logout, the Calls user must be deauthenticated and the VoIP or FCM token unregistered inside the app's existing sign-out function (`products/calls.md` "Sign out"); that is part of the change, not a hand-off step.

## Wired knowledge (populated and cited)
- `knowledge/curated/<platform>/products/calls.md` — configure or initialize, authenticate, incoming-call listener, background calls, sign out.
- `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` "Calls" — solved public cases for missed calls, the iOS VoIP crash, and media permissions.
- `knowledge/curated/<platform>/cross-cutting/push.md` — the Chat push setup; Calls registers its own VoIP or FCM token through the Calls SDK, not the Chat SDK.

## No-Fabrication
Every Calls API in the inserted code must come from the cited sections or the installed Calls SDK surface (`bash "${CLAUDE_PLUGIN_ROOT}/tools/local-sdk/read-surface.sh" <project> calls`). Android notification and foreground-service code uses Android APIs only and follows the public QuickStart cited in the Android section; never invent a Sendbird helper that shows the ringing UI. If a symptom is not covered by a verified source, say so and stop.
