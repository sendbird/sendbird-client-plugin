<!-- status: populated -->
# templates/android/compose/auth

Authentication (part of Chat) for a Compose app. The Chat SDK is headless, so the SDK calls are the
same as the View-host template (`templates/android/view/auth/SessionAuth.kt`), re-verified with
`javap` against the published sendbird-chat 4.36.4 and 4.36.5 AARs (2026-09-30). Only the
ViewModel/`StateFlow` wrapper is new. Compiled by `tools/templates/compile-check-android.sh`.

## Files
- `AuthViewModel.kt` — `installSessionHandler(fetchToken)`, `connect(userId, authToken)`, `logout()`
  exposed as `StateFlow<AuthState>`, plus an `AuthStatus` composable.

## How to splice
1. Uses the Chat SDK (`com.sendbird.sdk:sendbird-chat`); keep `SendbirdChat.init(...)` in your
   `Application` (`templates/android/view/chat/InitConnect.kt`).
2. Copy `AuthViewModel.kt`, adjust the package.
3. Call `vm.installSessionHandler { requester -> ... }` once, before `vm.connect(...)`. In the callback,
   fetch a fresh session token from your server, then `requester.onSuccess(token)` (or `onSuccess(null)`
   to skip, `onFail()` on error).
4. Drive it from a composable:
   ```kotlin
   @Composable
   fun LoginGate(vm: AuthViewModel = viewModel()) {
       AuthStatus(vm, onLoginRequired = { vm.connect("USER_ID", token) })
   }
   ```
   (`viewModel()` comes from `androidx.lifecycle:lifecycle-viewmodel-compose`, which `activity-compose` does not bring. Add it to the module's dependencies when the project does not have it yet, or the build fails with "Unresolved reference 'viewModel'"; see `knowledge/curated/android/hosts/compose.md`.)
5. Tokens are secrets — never hard-code or log them.

## Notes (see knowledge/curated/android/products/auth.md, all cited)
- `AuthState.SessionClosed` follows `SessionHandler.onSessionClosed()` — route the user to login.
- Logout: `SendbirdChat.disconnect { }` clears local data for the user.
