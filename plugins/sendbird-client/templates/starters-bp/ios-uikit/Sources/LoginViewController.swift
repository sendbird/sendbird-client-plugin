import UIKit

/// Sign-in screen. Replace the user ID field with your own sign-in and call
/// `LoginService().onLoginSucceeded(userId:)` once it succeeds.
final class LoginViewController: UIViewController {
    private let userIdField = UITextField()
    private let signInButton = UIButton(type: .system)
    private let noticeLabel = UILabel()
    private let appIdMissingLabel = UILabel()
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign in"
        view.backgroundColor = .systemBackground

        userIdField.placeholder = "User ID"
        userIdField.borderStyle = .roundedRect
        userIdField.autocapitalizationType = .none
        userIdField.autocorrectionType = .no
        userIdField.returnKeyType = .go
        userIdField.accessibilityIdentifier = "sb_login_user_id"   // BP17
        userIdField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        userIdField.addTarget(self, action: #selector(signIn), for: .editingDidEndOnExit)

        signInButton.setTitle("Sign in", for: .normal)
        signInButton.accessibilityIdentifier = "sb_login_button"
        signInButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)

        noticeLabel.numberOfLines = 0
        noticeLabel.textColor = .systemRed

        // BP02: a missing App ID is reported here instead of failing the build.
        appIdMissingLabel.numberOfLines = 0
        appIdMissingLabel.textColor = .systemRed
        appIdMissingLabel.text = "No App ID configured. Set SENDBIRD_APP_ID in Config/Sendbird.local.xcconfig and rebuild."
        appIdMissingLabel.accessibilityIdentifier = "sb_app_id_missing"
        appIdMissingLabel.isHidden = !AppConfig.sendbirdAppId.isEmpty

        let stack = UIStackView(arrangedSubviews: [appIdMissingLabel, userIdField, signInButton, noticeLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])

        observer = NotificationCenter.default.addObserver(
            forName: SendbirdSession.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        render()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    @objc private func textChanged() { render() }

    @objc private func signIn() {
        let userId = (userIdField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty, !AppConfig.sendbirdAppId.isEmpty else { return }
        // Your own sign-in goes here; on success:
        LoginService().onLoginSucceeded(userId: userId)
    }

    private func render() {
        let userId = (userIdField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        signInButton.isEnabled = !AppConfig.sendbirdAppId.isEmpty && !userId.isEmpty
        if case .signedOut(let notice) = SendbirdSession.shared.state {
            noticeLabel.text = notice
        }
    }
}
