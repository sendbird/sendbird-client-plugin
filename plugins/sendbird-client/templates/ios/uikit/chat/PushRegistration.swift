// source: SendbirdChatSDK.swiftinterface, verified by pinned/latest xcodebuild on 2026-09-22
import Foundation
import SendbirdChatSDK

func registerPushToken(_ token: Data) {
    SendbirdChat.registerDevicePushToken(token, unique: true) { _, _ in }
}

func unregisterPushToken(_ token: Data) {
    SendbirdChat.unregisterPushToken(token) { _ in }
}

func unregisterAllPushTokens() {
    SendbirdChat.unregisterAllPushToken { _ in }
}
