<!-- status: populated -->
# templates/ios/swiftui/chat

`ChatSession.swift` — an `ObservableObject` wrapping the verified Chat SDK calls so SwiftUI
views can observe connection state. The SDK calls are identical to the build-verified UIKit-host
template (`templates/ios/uikit/chat/InitConnect.swift`); only the SwiftUI/Combine wrapper is new.

## Splice steps
1. Add the Chat SDK via SPM: `github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, from `4.0.0`.
2. Copy `ChatSession.swift` into your app target.
3. Own it at the app root and drive it from the view lifecycle:
   ```swift
   @main
   struct MyApp: App {
       @StateObject private var chat = ChatSession()
       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(chat)
                   .task { chat.initialize(); chat.connect(userId: "USER_ID") }
           }
       }
   }
   ```
4. Read state in any view: `@EnvironmentObject var chat: ChatSession` → `chat.isConnected`, `chat.currentUser`.
5. Provide the App ID via the `SENDBIRD_APP_ID` env/build setting (do not hard-code). Authenticated
   apps connect with a token: `SendbirdChat.connect(userId:authToken:)`.

## Notes
- Message UI: Chat SDK is headless. For prebuilt SwiftUI chat screens use `SendbirdSwiftUI`
  (`templates/ios/swiftui/uikit`, which also notes how to wrap the UIViewController-based Sendbird UIKit).
- `@MainActor` keeps `@Published` updates on the main thread; SDK completion handlers hop back via `Task { @MainActor in ... }`.
