// source: https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials
// source: knowledge/curated/ios/hosts/swiftui.md ("Integration notes": AppDelegate bridge)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // BP01: initialize Sendbird once, at launch.
        SendbirdSession.shared.start()
        // BP10: push. After you add the Push Notifications capability and upload an APNs key on the
        // dashboard, ask for notification permission and call
        // application.registerForRemoteNotifications() here. The token arrives below.
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // BP10: registered for the signed-in user after connect (SendbirdSession).
        SendbirdSession.shared.didReceiveDeviceToken(deviceToken)
    }
}
