// source: knowledge/curated/ios/products/uikit.md ("Initialize (once, at launch)", "Set the current user (required)")
// source: knowledge/curated/ios/cross-cutting/troubleshooting.md ("UIKit shows every message on the left…": connect through SendbirdUI)
// source: knowledge/curated/ios/products/auth.md ("Token refresh — SessionDelegate")
// source: knowledge/curated/ios/products/chat.md ("Connection state and reconnection", "Call APIs only after connect completes")
// source: knowledge/curated/ios/cross-cutting/push.md ("One token, one device, one signed-in user")
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/SendbirdUI.swift#L649
// source: https://github.com/sendbird/sendbird-uikit-ios/blob/3.36.1/Sources/View/SBUViewControllerSet.swift#L13
// source: https://sendbird.com/docs/chat/sdk/v4/ios/ref/Classes/SendbirdChat.html
import Foundation
import SendbirdChatSDK
import SendbirdUIKit

/// BP16: the one app-wide Sendbird session. The sign-in screen, LoginService, a deep link, or a test
/// all call `SendbirdSession.shared`, and every screen observes `didChange`, so a sign-in from any
/// path moves the app to the signed-in screens.
@MainActor
final class SendbirdSession: NSObject {
    static let shared = SendbirdSession()
    static let didChange = Notification.Name("SendbirdSessionDidChange")

    enum Connection: Equatable { case connected, reconnecting, offline }

    enum State: Equatable {
        case signedOut(notice: String?)
        case connecting(userId: String)
        case signedIn(userId: String, connection: Connection)
    }

    private(set) var state: State = .signedOut(notice: nil) {
        didSet { NotificationCenter.default.post(name: Self.didChange, object: self) }
    }

    private static let connectionDelegateId = "starter-connection"
    private var initialized = false
    private var signingOut = false
    private var pendingUserId: String?
    private var deviceToken: Data?

    var userId: String? {
        switch state {
        case .signedOut: return nil
        case .connecting(let userId), .signedIn(let userId, _): return userId
        }
    }

    // MARK: - Launch

    /// BP01: initialize once, at launch (AppDelegate). BP12: theme before the first UIKit screen.
    func start() {
        guard !initialized, !AppConfig.sendbirdAppId.isEmpty else { return }
        StarterTheme.apply()
        // BP17: the conversation screen UIKit opens from the list is the starter's subclass, which
        // labels the message input and the send button.
        SBUViewControllerSet.GroupChannelViewController = ChannelViewController.self
        SendbirdUI.initialize(
            applicationId: AppConfig.sendbirdAppId,
            initParamsBuilder: { params in
                params?.isLocalCachingEnabled = true   // BP11 (UIKit 3.33.1 and later keep it on in any case)
            },
            completionHandler: { [weak self] error in
                Task { @MainActor in self?.didInitialize(error: error) }
            }
        )
    }

    private func didInitialize(error: SBError?) {
        if let error {
            pendingUserId = nil
            state = .signedOut(notice: "Initialization failed (\(error.code)).")
            return
        }
        initialized = true
        if let userId = pendingUserId {
            pendingUserId = nil
            state = .signedOut(notice: nil)
            signIn(userId: userId)
        }
    }

    // MARK: - Sign-in

    /// BP03: connect only after the app's own sign-in succeeded, with that user's ID.
    func signIn(userId rawUserId: String) {
        let userId = rawUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty, self.userId != userId else { return }
        guard initialized else {
            pendingUserId = userId   // signs in as soon as initialization completes
            state = .connecting(userId: userId)
            return
        }
        if signingOut || self.userId != nil {
            pendingUserId = userId   // signs in after the current user is signed out
            signOut()
            return
        }
        state = .connecting(userId: userId)
        // BP04 / BP07 / BP08: handlers are registered before connect and removed on sign-out.
        SendbirdChat.setSessionDelegate(self)
        SendbirdChat.addConnectionDelegate(self, identifier: Self.connectionDelegateId)
        TokenProvider.fetchSessionToken(userId: userId) { token in
            Task { @MainActor in
                guard self.state == .connecting(userId: userId) else { return }
                // BP05: UIKit needs the current user, and connects through SendbirdUI.
                SBUGlobals.currentUser = SBUUser(userId: userId)
                SBUGlobals.accessToken = token
                SendbirdUI.connect { user, error in
                    Task { @MainActor in self.didConnect(userId: userId, user: user, error: error) }
                }
            }
        }
    }

    private func didConnect(userId: String, user: User?, error: SBError?) {
        guard state == .connecting(userId: userId) else { return }   // signed out meanwhile
        guard user != nil, error == nil else {
            // BP13: show the code; the user signs in again.
            let notice = error.map { SendbirdErrorView($0, tokenSent: SBUGlobals.accessToken != nil).text } ?? "Could not connect. Try again."
            removeHandlers()
            SBUGlobals.currentUser = nil
            SBUGlobals.accessToken = nil
            state = .signedOut(notice: notice)
            return
        }
        // BP06: the home screen enables the channel list from here on. With the local cache, connect
        // can return the cached user while the socket is still opening; didConnect(userId:) follows.
        let open = SendbirdChat.getConnectState() == .open
        state = .signedIn(userId: userId, connection: open ? .connected : .reconnecting)
        registerPushTokenIfPossible()
    }

    // MARK: - Sign-out

    /// BP09: unregister this device's push token first, then disconnect in its completion.
    /// SendbirdUI.disconnect also clears SBUGlobals.currentUser and the user's local cache.
    func signOut(notice: String? = nil) {
        guard userId != nil, !signingOut else { return }
        guard initialized else {
            pendingUserId = nil
            state = .signedOut(notice: notice)
            return
        }
        signingOut = true
        removeHandlers()   // BP08
        SendbirdUI.unregisterPushToken { _ in
            SendbirdUI.disconnect {
                Task { @MainActor in self.didSignOut(notice: notice) }
            }
        }
    }

    private func didSignOut(notice: String?) {
        signingOut = false
        SBUGlobals.accessToken = nil
        state = .signedOut(notice: notice)
        if let next = pendingUserId {
            pendingUserId = nil
            signIn(userId: next)
        }
    }

    private func removeHandlers() {
        SendbirdChat.removeConnectionDelegate(forIdentifier: Self.connectionDelegateId)
        SendbirdChat.removeSessionDelegate()
    }

    // MARK: - Push

    /// BP10: AppDelegate hands the APNs token here. It is registered only for the signed-in user,
    /// after connect; a token that arrives earlier waits for the connection.
    func didReceiveDeviceToken(_ token: Data) {
        deviceToken = token
        registerPushTokenIfPossible()
    }

    private func registerPushTokenIfPossible() {
        guard case .signedIn = state, let deviceToken else { return }
        SendbirdUI.registerPush(deviceToken: deviceToken) { _ in }
    }

    fileprivate func setConnection(_ connection: Connection) {
        guard case .signedIn(let userId, _) = state else { return }
        state = .signedIn(userId: userId, connection: connection)
    }
}

// BP04: the session (token refresh) delegate, set before connect.
extension SendbirdSession: SessionDelegate {
    nonisolated func sessionTokenDidRequire(successCompletion success: @escaping (String?) -> Void,
                                            failCompletion fail: @escaping () -> Void) {
        Task { @MainActor in
            guard let userId = self.userId else { return fail() }
            TokenProvider.fetchSessionToken(userId: userId) { token in success(token) }
        }
    }

    nonisolated func sessionWasClosed() {
        Task { @MainActor in self.signOut(notice: "Your session ended. Sign in again.") }
    }
}

// BP07: the SDK reconnects by itself; this delegate only drives the status line.
extension SendbirdSession: ConnectionDelegate {
    nonisolated func didConnect(userId: String) {
        Task { @MainActor in self.setConnection(.connected) }
    }

    nonisolated func didStartReconnection() {
        Task { @MainActor in self.setConnection(.reconnecting) }
    }

    nonisolated func didSucceedReconnection() {
        Task { @MainActor in self.setConnection(.connected) }
    }

    nonisolated func didFailReconnection() {
        Task { @MainActor in self.setConnection(.offline) }
    }
}
