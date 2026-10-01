<!-- status: populated -->
# templates/ios/swiftui/uikit

Prebuilt chat UI on a SwiftUI host, using the **SwiftUI-native** package `SendbirdSwiftUI`
(`https://github.com/sendbird/sendbird-swiftui-ios`, product `SendbirdSwiftUI`, iOS 15+). Its views
(`GroupChannelListView`, `GroupChannelView`) are SwiftUI `View`s, so no `UIViewControllerRepresentable`
is needed. From the package README quickstart and its public sample app, with every symbol checked against
`SendbirdSwiftUI.swiftinterface` 1.2.2 (verified 2026-09-30). **Build-verified** against `SendbirdSwiftUI`
at the pinned and latest versions (`tools/templates/compile-check-ios.sh`, xcodebuild BUILD SUCCEEDED).

## Files
- `SendbirdChatUI.swift`:
  - `SendbirdChatUISession` — `start(userId:nickname:accessToken:)` runs `SendbirdUI.initialize`, sets
    `SBUGlobals.currentUser`, then `SendbirdUI.connect`; `signOut()` calls `SendbirdUI.disconnect`.
  - `SendbirdChatRootView` — spinner while initializing, then `GroupChannelListView()`.
  - `SendbirdChannelScreen(channelURL:)` — opens one channel with `GroupChannelView(provider:)`.

## How to splice
1. Add the package via SPM: `https://github.com/sendbird/sendbird-swiftui-ios`, product `SendbirdSwiftUI`, from `1.2.2`
   (it pulls `SendbirdChatSDK` and `SendbirdUIMessageTemplate` itself). The docs state it currently supports iPhone only, not iPad.
2. Copy `SendbirdChatUI.swift` into your app target.
3. Own the session at the app root and start it from the view lifecycle:
   ```swift
   @main
   struct MyApp: App {
       @StateObject private var chatUI = SendbirdChatUISession()
       var body: some Scene {
           WindowGroup {
               SendbirdChatRootView(session: chatUI, userId: "USER_ID")
                   .task { chatUI.start(userId: "USER_ID") }
           }
       }
   }
   ```
4. Provide the App ID via the `SENDBIRD_APP_ID` env/build setting (do not hard-code). Authenticated apps
   pass `accessToken:`; it is a secret.
5. Add the photo library, camera, and microphone usage strings the README lists for attachments.

## Variations (see knowledge/curated/ios/hosts/swiftui.md, all cited)
- Switching users: keep `.id(userId)` on the root view so the next user starts with fresh state.
- Keep customized view adaptors across `onDisappear`: set `GlobalOptions.enableViewAdaptorAutoReset = false` before the first SendbirdSwiftUI view appears.
- Feature toggles: `SendbirdUI.config.groupChannel.*` before the views appear (the public sample sets these before `SendbirdUI.initialize`).

## Using the UIViewController-based UIKit instead
If the app already uses Sendbird UIKit (`sendbird-uikit-ios-spm`, product `SendbirdUIKit`), its screens
are UIViewControllers. Init and current user are the same as the UIKit host
(`templates/ios/uikit/uikit/SetupUIKit.swift`); wrap `SBUGroupChannelListViewController` or
`SBUGroupChannelViewController(channelURL:)` in a `UIViewControllerRepresentable`. That is standard
SwiftUI↔UIKit interop, not an SDK API, and it is not build-verified as a separate template here.
