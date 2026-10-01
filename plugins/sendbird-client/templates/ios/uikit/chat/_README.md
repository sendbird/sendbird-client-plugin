<!-- status: populated -->
# templates/ios/uikit/chat

Chat init + connect + send on iOS (UIKit). From sendbird.com/docs (chat v4 ios
getting-started, verified 2026-06-09). **Build-verified**: compiles + links against
`SendbirdChatSDK` (xcodebuild BUILD SUCCEEDED, iOS Simulator).

## Files
- `InitConnect.swift` — `SendbirdChatBootstrap.initialize()` / `.connect(userId:)` / `.send(_:to:)`.

## How to splice
1. Add the SPM package `https://github.com/sendbird/sendbird-chat-sdk-ios` (product `SendbirdChatSDK`, from 4.0.0) — prefer SPM, do not add CocoaPods.
2. Call `SendbirdChatBootstrap.initialize()` once in `application(_:didFinishLaunchingWithOptions:)`.
3. Call `.connect(userId:)` after login. Read `SENDBIRD_APP_ID` from env — never hard-code; tokens are secrets.

## Variations (see knowledge/curated/ios/products/chat.md, all cited)
- Authenticated: `SendbirdChat.connect(userId:authToken:) { ... }`.
- Channels: load/create a `GroupChannel` before `send(_:to:)` (see docs for `GroupChannelCreateParams`).
