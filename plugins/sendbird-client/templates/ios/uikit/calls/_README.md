<!-- status: populated -->
# templates/ios/uikit/calls

Sendbird Calls (voice/video) on iOS. From the public `sendbird-calls-ios` README
(verified 2026-06-09). **Build-verified** against `SendBirdCalls` (xcodebuild BUILD
SUCCEEDED, generic/platform=iOS device arch; the binary's simulator slice has an arch
limit in this Xcode).

## Files
- `SetupCalls.swift` — `configure()` / `authenticate(...)` / `dial(...)`.

## How to splice
1. SPM only: package `https://github.com/sendbird/sendbird-calls-ios`, product `SendBirdCalls` (iOS 14+; pulls WebRTC).
2. `SendbirdCallsBootstrap.configure()` at launch, then `authenticate(...)`.
3. Add a `SendBirdCallDelegate` to receive incoming calls; register a VoIP push token for background calls.
4. App ID from the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting (see `knowledge/curated/ios/setup.md` "App ID") — never hard-code; access token is a secret.

## Variations (see knowledge/curated/ios/products/calls.md, all cited)
- Video call: `dial(calleeId:video: true)`.
