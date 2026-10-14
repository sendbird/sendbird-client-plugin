<!-- status: populated -->
# templates/ios/swiftui/chat

`ChatSession.swift` — an `ObservableObject` wrapping the verified Chat SDK calls so SwiftUI
views can observe connection state. The SDK calls are identical to the build-verified UIKit-host
template (`templates/ios/uikit/chat/InitConnect.swift`); only the SwiftUI/Combine wrapper is new.

## Splice steps
1. Add the Chat SDK via SPM: `github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, from `4.0.0`.
2. Copy `ChatSession.swift` into your app target.
3. Use the one shared session: initialize it at launch, show it from the app root, and connect from the app's
   own sign-in code (see `knowledge/curated/ios/hosts/swiftui.md` "Start the session from the app's sign-in"):
   ```swift
   @main
   struct MyApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(ChatSession.shared)
                   .task { ChatSession.shared.initialize() }
           }
       }
   }

   // In the app's sign-in success handler, whatever type or thread it runs on:
   Task { @MainActor in ChatSession.shared.connect(userId: userId) }
   ```
4. Read state in any view: `@EnvironmentObject var chat: ChatSession` → `chat.isConnected`, `chat.currentUser`.
5. Provide the App ID through the `SENDBIRD_APP_ID` Info.plist key, filled by the `SENDBIRD_APP_ID` build setting
   (see `knowledge/curated/ios/setup.md` "App ID"; do not hard-code). Authenticated
   apps connect with a token: `SendbirdChat.connect(userId:authToken:)`.

## Notes
- Message UI: Chat SDK is headless. For prebuilt SwiftUI chat screens use `SendbirdSwiftUI`
  (`templates/ios/swiftui/uikit`, which also notes how to wrap the UIViewController-based Sendbird UIKit).
- `@MainActor` keeps `@Published` updates on the main thread; SDK completion handlers hop back via `Task { @MainActor in ... }`.
