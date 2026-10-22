---
name: push-setup
description: Set up push notifications for Sendbird — APNS (cert or .p8) on iOS, FCM/HMS on Android, Web Push / RN on JS — including dashboard upload steps, token registration, payload, and deeplink handling. Use when the customer asks about push or notifications are not arriving.
argument-hint: "[--product chat,calls]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:push-setup

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. Hand work to that agent by calling the `Agent` tool once with the agent as Claude Code lists it: this plugin's name, a colon, then the name the router printed (for example `sendbird-client:sendbird-ios-agent`). In Codex, which has no `Agent` tool, run that agent's launcher skill instead (for example `$sendbird-client:sendbird-ios-agent`) and start the agent only as that skill says; it sets the model and settings the agent needs. Do not do the agent's part yourself, even in a small project: write or edit no project source file in this session, before or after the hand-off, also when the customer confirms a change in a later turn. If the hand-off fails, say that this part was not done.
Before anything else, check every product the request names (AI Agent, its messenger or launcher, is `ai-agent`; the others are `chat`, `uikit`, `calls`, `desk`, and `live`) with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir> --check <product>`, one run per product. Printing the scope without `--check` is not this check. When it exits 1, change nothing and hand nothing to an agent: say what it printed (out of the configured scope, or not supported yet) and that `SENDBIRD_PRODUCTS` or `enabledProducts` in `.sendbird-client/profile.json` sets the scope; a non-interactive run ends with `status: "declined"`.

Push end-to-end for the detected platform.

## Steps
1. Detect platform + push provider (Tier-2 detector) + products. Ask once if unknown.
2. Walk the provider path (APNS cert vs .p8 / FCM / Web Push / RN), cite the dashboard-config docs (do NOT invent dashboard click-paths), then hand off to the platform agent for token-registration + payload + deeplink code from the wired sources below.
   On Android, apply the `com.google.gms.google-services` Gradle plugin only when `app/google-services.json` exists, and never create a placeholder file. An unconditional apply fails the build when the file is missing. When the file is absent, leave the plugin out (or apply it conditionally) and list "download `google-services.json` from your Firebase project into `app/`" as a customer hand-off step (`knowledge/curated/android/cross-cutting/push.md` "Setup checklist").
3. Cover foreground/background, Android 13+ POST_NOTIFICATIONS, VoIP push when Calls is present.
   On logout, unregister the token before disconnecting, inside the app's existing sign-out or logout function; use the unregister call in `knowledge/curated/<platform>/cross-cutting/push.md`. A token left registered keeps sending the previous user's notifications to this device.
4. End with a test-message checklist.

## Wired knowledge (populated and cited)
- Token registration: `knowledge/curated/<platform>/cross-cutting/push.md` — iOS `registerDevicePushToken`/`unregisterPushToken`/`unregisterAllPushToken` (build-verified); Android `SendbirdPushHandler` subclass + `SendbirdPushHelper.registerHandler(...)`; JS `registerFCM/APNSPushTokenForCurrentUser` + unregister variants (type-checked).
- Notifications not arriving: also read `knowledge/curated/<platform>/cross-cutting/troubleshooting.md` and answer with the API its matching entry names. For example, on Android a push that arrives in the background but never after the app is swiped away means init and handler registration run in an Activity instead of `Application.onCreate()`.
- VoIP for Calls: registered via the Calls SDK (`SendBirdCall.registerVoIPPush`) — the Chat SDK's PushKit method was REMOVED; see `knowledge/curated/ios/products/calls.md`. Do not emit the removed API.

## No-Fabrication
Token-registration APIs and payload keys must be verified + cited. Dashboard navigation is linked to docs, never reproduced from memory. Unverified -> say so.
