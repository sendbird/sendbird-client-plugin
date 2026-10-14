import UIKit

/// Home screen after sign-in: who is signed in, the connection status, the channel list, sign-out.
final class HomeViewController: UIViewController {
    private let userLabel = UILabel()
    private let statusLabel = UILabel()
    private let channelsButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        view.backgroundColor = .systemBackground

        statusLabel.textColor = .secondaryLabel
        statusLabel.accessibilityIdentifier = "sb_connection_status"   // BP17

        channelsButton.setTitle("Channels", for: .normal)
        channelsButton.accessibilityIdentifier = "sb_open_channels"
        channelsButton.addTarget(self, action: #selector(openChannels), for: .touchUpInside)

        signOutButton.setTitle("Sign out", for: .normal)
        signOutButton.accessibilityIdentifier = "sb_logout_button"
        signOutButton.addTarget(self, action: #selector(signOut), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [userLabel, statusLabel, channelsButton, signOutButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
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

    private func render() {
        switch SendbirdSession.shared.state {
        case .signedOut:
            userLabel.text = nil
            statusLabel.text = "Signed out"
            channelsButton.isHidden = true
        case .connecting(let userId):
            userLabel.text = "Signed in as \(userId)"
            statusLabel.text = "Connecting…"
            channelsButton.isHidden = true   // BP06: nothing that calls the server before connect returns
        case .signedIn(let userId, let connection):
            userLabel.text = "Signed in as \(userId)"
            switch connection {
            case .connected: statusLabel.text = "Connected"
            case .reconnecting: statusLabel.text = "Reconnecting…"
            case .offline: statusLabel.text = "Offline"
            }
            channelsButton.isHidden = false
        }
    }

    @objc private func openChannels() {
        navigationController?.pushViewController(ChannelListViewController(), animated: true)
    }

    @objc private func signOut() {
        LoginService().onLogout()
    }
}
