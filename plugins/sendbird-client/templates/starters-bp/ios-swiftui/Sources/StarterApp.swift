import SwiftUI

@main
struct StarterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Shows the sign-in screen while signed out and the home screen otherwise. It observes the one
/// app-wide session (BP16), whichever code path signed in.
struct RootView: View {
    @ObservedObject private var session = SendbirdSession.shared

    var body: some View {
        switch session.state {
        case .signedOut(let notice):
            LoginView(notice: notice)
        case .connecting(let userId):
            HomeView(userId: userId, status: "Connecting…", ready: false)
        case .signedIn(let userId, let connection):
            HomeView(userId: userId, status: connection.label, ready: true)
        }
    }
}

private extension SendbirdSession.Connection {
    var label: String {
        switch self {
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting…"
        case .offline: return "Offline"
        }
    }
}
