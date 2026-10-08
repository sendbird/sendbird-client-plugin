import Foundation

/// The app's own sign-in. Sendbird connects here after your sign-in succeeds,
/// and disconnects in onLogout.
final class LoginService {
    func onLoginSucceeded(userId: String) {
        // Sendbird connect goes here.
        _ = userId
    }

    func onLogout() {
        // Sendbird disconnect goes here.
    }
}
