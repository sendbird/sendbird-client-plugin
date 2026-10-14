import SwiftUI

/// Sign-in screen. Replace the user ID field with your own sign-in and call
/// `LoginService().onLoginSucceeded(userId:)` once it succeeds.
struct LoginView: View {
    let notice: String?
    @State private var userId = ""

    private var appIdMissing: Bool { AppConfig.sendbirdAppId.isEmpty }
    private var trimmed: String { userId.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationView {
            Form {
                if appIdMissing {
                    // BP02: a missing App ID is reported here instead of failing the build.
                    Text("No App ID configured. Set SENDBIRD_APP_ID in Config/Sendbird.local.xcconfig and rebuild.")
                        .foregroundColor(.red)
                        .accessibilityIdentifier("sb_app_id_missing")
                }
                TextField("User ID", text: $userId)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("sb_login_user_id")   // BP17
                    .onSubmit(signIn)
                Button("Sign in", action: signIn)
                    .disabled(appIdMissing || trimmed.isEmpty)
                    .accessibilityIdentifier("sb_login_button")
                if let notice {
                    Text(notice).foregroundColor(.red)
                }
            }
            .navigationTitle("Sign in")
        }
        .navigationViewStyle(.stack)
    }

    private func signIn() {
        guard !appIdMissing, !trimmed.isEmpty else { return }
        // Your own sign-in goes here; on success:
        LoginService().onLoginSucceeded(userId: trimmed)
    }
}
