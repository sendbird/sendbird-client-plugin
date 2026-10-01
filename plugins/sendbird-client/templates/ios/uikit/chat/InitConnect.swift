// source: https://sendbird.com/docs/chat/sdk/v4/ios/getting-started/send-first-message (verified 2026-06-09)
// Build-verified: InitParams / SendbirdChat.initialize / SendbirdChat.connect / sendUserMessage
// compile + link against SendbirdChatSDK (xcodebuild BUILD SUCCEEDED, 2026-06-09).
// SPM: https://github.com/sendbird/sendbird-chat-sdk-ios , product SendbirdChatSDK, from 4.0.0.
// App ID from env/build setting; session/access tokens are secrets — never hard-code.

import Foundation
import SendbirdChatSDK

private let appId = ProcessInfo.processInfo.environment["SENDBIRD_APP_ID"] ?? "YOUR_SENDBIRD_APP_ID"

enum SendbirdChatBootstrap {
    // Call once at launch (e.g. application(_:didFinishLaunchingWithOptions:)).
    static func initialize() {
        let params = InitParams(applicationId: appId, isLocalCachingEnabled: true, needsSynchronous: false)
        SendbirdChat.initialize(params: params,
                                migrationStartHandler: { },
                                completionHandler: { error in
            if let error = error { print("Sendbird init failed: \(error)") }
        })
    }

    // Connect after init. For authenticated apps pass an access/session token:
    // SendbirdChat.connect(userId: userId, authToken: token) { ... }
    static func connect(userId: String, completion: @escaping (User?) -> Void) {
        SendbirdChat.connect(userId: userId) { user, error in
            guard let user = user, error == nil else { completion(nil); return }
            completion(user)
        }
    }

    // Send a text message to an already-loaded GroupChannel.
    static func send(_ text: String, to channel: GroupChannel) {
        channel.sendUserMessage(text) { message, error in
            guard message != nil, error == nil else { return }
            // sent
        }
    }
}
