import UIKit

/// Shows the sign-in screen while signed out and the home screen otherwise. It follows the one
/// app-wide session (BP16), whichever code path signed in.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let navigation = UINavigationController()
    private var observer: NSObjectProtocol?
    private var signedIn: Bool?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
        observer = NotificationCenter.default.addObserver(
            forName: SendbirdSession.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showScreenForSession() }
        }
        showScreenForSession()
    }

    @MainActor
    private func showScreenForSession() {
        let isSignedIn: Bool
        if case .signedOut = SendbirdSession.shared.state { isSignedIn = false } else { isSignedIn = true }
        guard isSignedIn != signedIn else { return }
        signedIn = isSignedIn
        let root: UIViewController = isSignedIn ? HomeViewController() : LoginViewController()
        navigation.setViewControllers([root], animated: false)
    }
}
