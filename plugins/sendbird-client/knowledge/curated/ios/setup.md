<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 / sendbird-uikit-ios 3.36.1 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — setup

> Verified against the public mirrors and rebuilt against the latest SPM releases on 2026-09-08. Shared-dependency minimums read from the public `Package.swift` manifests on 2026-09-30. Prefer SPM; cite each coordinate. Do not invent versions.

## Overview
Add the SDK(s) you need via Swift Package Manager, initialize once at launch, then connect/authenticate. Packaging is SPM-first.

## Packaging — prefer Swift Package Manager
- Default to SPM for new integrations. Chat v4 ships SPM at `github.com/sendbird/sendbird-chat-sdk-ios` (product `SendbirdChatSDK`, from 4.0.0); UIKit at `github.com/sendbird/sendbird-uikit-ios-spm` (products `SendbirdUIKit`, `SendbirdUIMessageTemplate`).
- The `sendbird-chat-ios-spm` mirror is LEGACY v3 (`SendBirdSDK`) — do not use it for v4.
- Calls (`sendbird-calls-ios`), Live (`sendbird-live-sdk-ios`), Desk (`SendBird-Desk-iOS-Framework`) all ship SPM too.
- Use CocoaPods only when the project already has a `Podfile`. Do not introduce CocoaPods into an SPM or fresh project.
- XcodeGen projects: declare packages under `packages:` in `project.yml` and add the product under the target's `dependencies:`; `xcodegen generate` writes the SPM refs into the `.xcodeproj` (no `.xcworkspace`).

## Keep shared dependencies compatible

Swift Package Manager resolves a single version of `sendbird-chat-sdk-ios` (and of `sendbird-uikit-ios-spm`) for the whole app, so the version you pin must satisfy the minimum declared by every Sendbird package you add. Minimums declared in the current public manifests:

| Package (version) | Requires |
|---|---|
| `sendbird-uikit-ios-spm` 3.36.0 | Chat SDK 4.39.6+ |
| `sendbird-swiftui-ios` 1.2.2 | Chat SDK 4.39.6+, `sendbird-uikit-ios-spm` 3.35.5+ |
| `SendBird-Desk-iOS-Framework` v1.2.2 | Chat SDK 4.39.5+ |

When you upgrade one Sendbird package, check its `Package.swift` and raise the shared pins if needed instead of pinning them exactly to an older release.

(source: Package.swift of sendbird/sendbird-uikit-ios-spm@3.36.0 line 23, sendbird/sendbird-swiftui-ios@1.2.2 lines 19 and 23, sendbird/SendBird-Desk-iOS-Framework@v1.2.2 line 17; README Requirements of sendbird-uikit-ios-spm@3.36.0 and SendBird-Desk-iOS-Framework@v1.2.2)

## Common tasks
- Initialize Chat: see knowledge/curated/ios/products/chat.md (build-verified).
- Prebuilt UI: knowledge/curated/ios/products/uikit.md.
- Auth/session: knowledge/curated/ios/products/auth.md.

## Pitfalls
- Binary frameworks (Calls/Live/AI Agent Core) may need a device build (simulator slice arch limits).
- App ID from config/env; tokens are secrets — never hard-code.

## Related
- Architecture: knowledge/curated/ios/architecture.md
- Official docs: https://sendbird.com/docs
