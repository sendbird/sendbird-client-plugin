---
name: push-setup
description: Set up push notifications for Sendbird — APNS (cert or .p8) on iOS, FCM/HMS on Android, Web Push / RN on JS — including dashboard upload steps, token registration, payload, and deeplink handling. Use when the customer asks about push or notifications are not arriving.
argument-hint: "[--product chat,calls]"
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, Agent
---

# /sendbird-client:push-setup

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`.
Resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code` before delegating.
Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>` and decline out-of-scope products.

Push end-to-end for the detected platform.

## Steps
1. Detect platform + push provider (Tier-2 detector) + products. Ask once if unknown.
2. Walk the provider path (APNS cert vs .p8 / FCM / Web Push / RN), cite the dashboard-config docs (do NOT invent dashboard click-paths), then hand off to the platform agent for token-registration + payload + deeplink code from the wired sources below.
3. Cover foreground/background, Android 13+ POST_NOTIFICATIONS, VoIP push when Calls is present.
4. End with a test-message checklist.

## Wired knowledge (populated and cited)
- Token registration: `knowledge/curated/<platform>/cross-cutting/push.md` — iOS `registerDevicePushToken`/`unregisterPushToken`/`unregisterAllPushToken` (build-verified); Android `SendbirdPushHandler` subclass + `SendbirdPushHelper.registerHandler(...)`; JS `registerFCM/APNSPushTokenForCurrentUser` + unregister variants (type-checked).
- VoIP for Calls: registered via the Calls SDK (`SendBirdCall.registerVoIPPush`) — the Chat SDK's PushKit method was REMOVED; see `knowledge/curated/ios/products/calls.md`. Do not emit the removed API.

## No-Fabrication
Token-registration APIs and payload keys must be verified + cited. Dashboard navigation is linked to docs, never reproduced from memory. Unverified -> say so.
