import UIKit

// The window and React Native start in SceneDelegate.swift: apps built with the iOS 27 SDK must use
// the scene life cycle (the React Native 0.88 template is laid out the same way).
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  // Stays nil (the window belongs to the scene). Declared because some native modules read
  // UIApplication.shared.delegate.window at launch; React Native Firebase Messaging 19.3.0 does,
  // and an app delegate without this property stops at launch with "unrecognized selector".
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    true
  }
}
