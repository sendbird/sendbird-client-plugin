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
3. Use the one shared session. Show it from the app root, and start it from the app's own sign-in code
   (source: knowledge/curated/ios/hosts/swiftui.md "Start the session from the app's sign-in"):
   ```swift
   @main
   struct MyApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(SendbirdChatUISession.shared)
           }
       }
   }

   // In the app's sign-in success handler, whatever type or thread it runs on:
   Task { @MainActor in SendbirdChatUISession.shared.start(userId: userId) }
   // In its logout handler:
   Task { @MainActor in SendbirdChatUISession.shared.signOut() }
   ```
   A chat view reads it with `@EnvironmentObject private var chatUI: SendbirdChatUISession` and shows
   `SendbirdChatRootView(session: chatUI, userId: id)` once `chatUI.userId` is set. Do not pass the session to
   the sign-in object through a `weak` property set in `.onAppear`: sign-in then works only on that one
   instance, and on any other instance it silently does nothing.
4. Provide the App ID through the Info.plist key `SENDBIRD_APP_ID` set to `$(SENDBIRD_APP_ID)`, and define the
   `SENDBIRD_APP_ID` build setting (see `knowledge/curated/ios/setup.md` "App ID"). The template reads that key
   and falls back to the environment variable, which exists only when Xcode launches the app. Do not hard-code.
   Authenticated apps pass `accessToken:`; it is a secret.
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
