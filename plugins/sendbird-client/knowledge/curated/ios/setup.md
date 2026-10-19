<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 / sendbird-uikit-ios 3.36.1 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — setup

> Verified against the public mirrors and rebuilt against the latest SPM releases on 2026-09-08. Shared-dependency minimums read from the public `Package.swift` manifests on 2026-09-30. Prefer SPM; cite each coordinate. Do not invent versions.

> A plugin run does not build, compile, or type-check the project: do not run `xcodebuild build`, `xcodegen generate`, or `swift build` unless the customer asks for a build (`docs/AGENT_CONTRACT.md` section 3). The rebuilds above are the plugin's own tests.

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

### Keep UIKit and raise only the Chat SDK

UIKit does not pin the Chat SDK to one release. At tag 3.36.1, `sendbird-uikit-ios-spm` declares `.package(name: "SendbirdChatSDK", url: "https://github.com/sendbird/sendbird-chat-sdk-ios", from: "4.39.6")`. In SwiftPM, `from:` means "this version or newer, up to the next major version", so any 4.x release from 4.39.6 satisfies UIKit. To run a newer Chat SDK under the same UIKit version, add `sendbird-chat-sdk-ios` to the app yourself with a higher minimum, for example `from: "4.39.11"`. SwiftPM then resolves the one shared version to 4.39.11 or later. The version it picked is recorded in `Package.resolved`. A 5.x Chat SDK would fall outside UIKit's range and fail to resolve.

(source: https://github.com/sendbird/sendbird-uikit-ios-spm/blob/3.36.1/Package.swift#L19-L25; https://github.com/swiftlang/swift-package-manager/blob/swift-6.0-RELEASE/Sources/PackageDescription/PackageDependency.swift#L196-L223 — `from:` is `.upToNextMajor(from:)`)

(source: Package.swift of sendbird/sendbird-uikit-ios-spm@3.36.0 line 23, sendbird/sendbird-swiftui-ios@1.2.2 lines 19 and 23, sendbird/SendBird-Desk-iOS-Framework@v1.2.2 line 17; README Requirements of sendbird-uikit-ios-spm@3.36.0 and SendBird-Desk-iOS-Framework@v1.2.2)

## App ID

Read the App ID from the app's Info.plist, filled in from a build setting, so the value is there however the app is launched. An environment variable set in the Xcode scheme exists only when Xcode or a test runner launches the app. When the user opens the app from the home screen, `ProcessInfo.processInfo.environment` does not contain it, and the SDK initializes with the placeholder instead of the real App ID.

1. Define the build setting `SENDBIRD_APP_ID` (in an `.xcconfig` file, the target's build settings, or XcodeGen `settings.base`).
2. Add the Info.plist key `SENDBIRD_APP_ID` with the value `$(SENDBIRD_APP_ID)`. With XcodeGen, put it under the target's `info.properties`.
3. Read it once at launch. The iOS templates do this and keep the environment variable only as a development fallback:

```swift
enum SendbirdAppConfig {
    static let appId: String = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SENDBIRD_APP_ID") as? String,
           !value.isEmpty, !value.hasPrefix("$(") {
            return value
        }
        return ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"
    }()
}
```

If the project already supplies the App ID another way, such as an existing config or constants file, keep that way. The App ID identifies the application and is not a secret; access and session tokens are, so they never go into Info.plist or source.

(source: templates/ios/uikit/chat/InitConnect.swift, build-verified with tools/templates/compile-check-ios.sh against the pinned and latest SPM packages on 2026-10-14. The environment-only failure was seen on 2026-10-13 when generated apps ran on an iOS simulator.)

## Common tasks
- Initialize Chat: see knowledge/curated/ios/products/chat.md (build-verified).
- Prebuilt UI: knowledge/curated/ios/products/uikit.md.
- Auth/session: knowledge/curated/ios/products/auth.md.

## Pitfalls
- Binary frameworks (Calls/Live/AI Agent Core) may need a device build (simulator slice arch limits).
- App ID from the Info.plist build setting (see "App ID" above); tokens are secrets — never hard-code.
- One App ID per app run. The authentication docs say the initialize method "must be called once across your client app", and they describe no way to switch to another App ID at runtime; keep development and production App IDs in separate build configurations. (source: https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication)

## Related
- Architecture: knowledge/curated/ios/architecture.md
- Official docs: https://sendbird.com/docs
