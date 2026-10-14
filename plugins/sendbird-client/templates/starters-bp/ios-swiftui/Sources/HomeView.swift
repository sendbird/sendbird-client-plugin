// source: knowledge/curated/ios/hosts/swiftui.md ("SwiftUI-native chat views (SendbirdSwiftUI)", "Switching users and keeping custom views")
// source: knowledge/curated/ios/cross-cutting/troubleshooting.md ("Sendbird SwiftUI screens show two navigation bars")
import SwiftUI
import SendbirdSwiftUI

/// Home screen after sign-in: who is signed in, the connection status, the channel list, sign-out.
struct HomeView: View {
    let userId: String
    let status: String
    /// true once connect returned (BP06); the channel list is offered only then.
    let ready: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Signed in as \(userId)")
                Text(status)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("sb_connection_status")   // BP17
                if ready {
                    NavigationLink(destination: ChannelListScreen(userId: userId)) { Text("Channels") }
                        .accessibilityIdentifier("sb_open_channels")
                }
                Button("Sign out") { LoginService().onLogout() }
                    .accessibilityIdentifier("sb_logout_button")
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .navigationTitle("Home")
        }
        .navigationViewStyle(.stack)
    }
}

/// The SendbirdSwiftUI channel list. Tapping a row opens the SendbirdSwiftUI conversation view.
struct ChannelListScreen: View {
    let userId: String

    var body: some View {
        GroupChannelListView()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("sb_channel_list")   // BP17
            .navigationBarHidden(true)   // BP14: the Sendbird view brings its own navigation bar
    }
}
