<!-- status: populated -->
# templates/ios/swiftui/auth

Authentication (part of Chat) on a SwiftUI host: session-token connect, token refresh via
`SessionDelegate`, and logout, exposed as an `ObservableObject`. From sendbird.com/docs +
`SendbirdChatSDK.swiftinterface` 4.39.11 (verified 2026-09-30). The SDK calls are the same as the
UIKit-host template (`templates/ios/uikit/auth/SessionAuth.swift`); only the SwiftUI/Combine wrapper is
new. **Build-verified** against `SendbirdChatSDK` at the pinned and latest versions
(`tools/templates/compile-check-ios.sh`, xcodebuild BUILD SUCCEEDED).

## Files
- `AuthSession.swift` — `start()` (register delegate) / `signIn(userId:sessionToken:)` / `signOut()`, a
  published `status` (`signedOut`, `connecting`, `signedIn`, `sessionClosed`), and the `SessionDelegate`
  callbacks, each hopping to the main actor.

## How to splice
1. Add the Chat SDK via SPM: `github.com/sendbird/sendbird-chat-sdk-ios`, product `SendbirdChatSDK`, from `4.0.0`.
2. Copy `AuthSession.swift` into your app target. Initialize Chat first (`templates/ios/swiftui/chat/ChatSession.swift`).
3. Own it at the app root, passing a closure that fetches a fresh session token from your server:
   ```swift
   @main
   struct MyApp: App {
       @StateObject private var auth = AuthSession { completion in
           // Call your server, then completion(TOKEN) — or completion(nil) on failure.
           completion(nil)
       }
       var body: some Scene {
           WindowGroup {
               RootView()
                   .environmentObject(auth)
                   .task { auth.start() }
           }
       }
   }
   ```
4. Call `auth.signIn(userId:sessionToken:)` after login, and switch the root view on `auth.status`
   (`.sessionClosed` means the session ended; send the user back to login).
5. Tokens are secrets — never hard-code or log them.

## Notes (see knowledge/curated/ios/products/auth.md, all cited)
- `SendbirdChat.setSessionDelegate(_:)`, `SendbirdChatOptions.setSessionTokenRefreshTimeout(_:)`.
- Logout: `SendbirdChat.disconnect` (full) / `disconnectWebSocket` (keep cache).
- The delegate methods are `nonisolated` and hop to the main actor, because the SDK does not promise to call them on the main thread.
