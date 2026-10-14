import Foundation

/// The app's own sign-in calls these. Sendbird connects after `onLoginSucceeded` and disconnects in
/// `onLogout`. Any instance works: both forward to the one app-wide session (BP16), so a sign-in
/// from the sign-in screen, a deep link, or a test reaches the same place.
final class LoginService {
    func onLoginSucceeded(userId: String) {
        Task { @MainActor in SendbirdSession.shared.signIn(userId: userId) }
    }

    func onLogout() {
        Task { @MainActor in SendbirdSession.shared.signOut() }
    }
}
