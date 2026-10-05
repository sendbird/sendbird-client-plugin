// source: https://github.com/sendbird/sendbird-calls-ios (README implementation guide, verified 2026-06-09)
// Build-verified: SendBirdCall.configure / AuthenticateParams / authenticate / DialParams /
// CallOptions / dial compile + link against SendBirdCalls (xcodebuild BUILD SUCCEEDED for
// generic/platform=iOS, 2026-06-09; the binary framework's simulator slice has an arch limit
// in this Xcode, so verify on a device destination).
// SPM only: https://github.com/sendbird/sendbird-calls-ios , product SendBirdCalls (iOS 14+).
// App ID from env; access token is a secret — never hard-code.

import Foundation
import SendBirdCalls

private let appId = ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"

enum SendbirdCallsBootstrap {
    static func configure() {
        SendBirdCall.configure(appId: appId)
    }

    static func authenticate(userId: String, accessToken: String?, completion: @escaping (Bool) -> Void) {
        let params = AuthenticateParams(userId: userId, accessToken: accessToken)
        SendBirdCall.authenticate(with: params) { _, error in
            completion(error == nil)
        }
    }

    // Make a 1:1 direct call.
    static func dial(calleeId: String, video: Bool = false) {
        let dialParams = DialParams(calleeId: calleeId, isVideoCall: video, callOptions: CallOptions(), customItems: [:])
        _ = SendBirdCall.dial(with: dialParams) { _, error in
            if let error = error { print("dial failed: \(error)") }
        }
    }
}
