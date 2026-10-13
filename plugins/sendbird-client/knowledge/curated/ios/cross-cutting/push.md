<!-- last-verified-against: sendbird-chat-sdk-ios 4.39.11 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-ios -->
<!-- status: populated -->
# ios — push

> Push APIs read from the SDK's own `SendbirdChatSDK.swiftinterface`, verified 2026-09-30. register/unregister, logout order, and the Notification Service Extension snippet build-verified (xcodebuild). The pending-token and payload sections were added on 2026-10-11 from the 4.39.11 interface and the iOS push registration page. Used by `/sendbird-client:push-setup`. Do not invent API.

## Overview
iOS push uses APNs. Register the device's APNs token with Sendbird after the user connects; register a PushKit (VoIP) token for Calls. Upload your APNs auth key / certificate on the Sendbird dashboard.

## Register / unregister the APNs token
```swift
import SendbirdChatSDK

// In application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
SendbirdChat.registerDevicePushToken(deviceToken, unique: true) { status, error in
    // status: PushTokenRegistrationStatus
}

// On logout:
SendbirdChat.unregisterPushToken(deviceToken) { error in }
// or SendbirdChat.unregisterAllPushToken { error in }
```
(source: SendbirdChatSDK.swiftinterface — `registerDevicePushToken(_:unique:completionHandler:)`, `unregisterPushToken(_:completionHandler:)`, `unregisterAllPushToken(completionHandler:)`, `PushTokenRegistrationStatus`; build-verified)

## One token, one device, one signed-in user

An APNs device token identifies one app install, so register it only for the user who is currently signed in on that device. `SendbirdChat.disconnect` does not stop push — a disconnected user still receives notifications for their group channels — so on logout unregister this device's token first and disconnect in its completion; otherwise the device keeps receiving the previous user's notifications. With `registerDevicePushToken(_:unique:completionHandler:)`, `unique: true` removes all tokens previously registered for the user and keeps only this one; `unique: false` (same as `registerDevicePushTokenForMultiDevicePush(_:completionHandler:)`) adds it alongside the others.

```swift
import Foundation
import SendbirdChatSDK
import SendbirdUIKit

// Chat SDK: remove this device's token, then disconnect.
func logOut(deviceToken: Data) {
    SendbirdChat.unregisterPushToken(deviceToken) { error in
        SendbirdChat.disconnect { }
    }
}

// UIKit (SendbirdSwiftUI has the same SendbirdUI calls): same order.
func logOutUIKit() {
    SendbirdUI.unregisterPushToken { success in
        SendbirdUI.disconnect { }
    }
}
```

(source: SendbirdChatSDK.swiftinterface (4.39.10) lines 6392, 6395, 6402, 6409; SendbirdUIKit.swiftinterface (3.36.0) lines 16569–16570; https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials; https://sendbird.com/docs/chat/sdk/v4/ios/application/authenticating-a-user/authentication; https://sendbird.com/docs/chat/uikit/v3/swiftui/essentials/authentication)

## Token registered before connect (pending)

If the device token arrives before the user is connected, registration returns `PushTokenRegistrationStatus.pending`. Register it again from the `connect` completion with `SendbirdChat.getPendingPushToken()`.

```swift
import SendbirdChatSDK

func connectAndRegisterPendingToken() {
    SendbirdChat.connect(userId: USER_ID) { user, error in
        guard error == nil, let token = SendbirdChat.getPendingPushToken() else { return }
        SendbirdChat.registerDevicePushTokenForMultiDevicePush(token) { status, error in }
    }
}
```

(source: SendbirdChatSDK.swiftinterface (4.39.11) lines 6393 `getPendingPushToken()`, 6396 `registerDevicePushTokenForMultiDevicePush(_:completionHandler:)`, 5744 `PushTokenRegistrationStatus.pending`, 6318 `connect(userId:completionHandler:)`; source: https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials — reviewed 2026-10-11)

## Handle a notification payload (background and tap)

Sendbird sends APNs an alert (`{sender's nickname}: {text message}`), the default sound, and a badge with the user's total unread message count (the badge can be turned off in the dashboard). The push also carries a JSON object under the `sendbird` key: `type` (`MESG`, `FILE`, or `ADMM` for an admin message), `message`, `channel.channel_url`, `sender`, `unread_message_count`, and more. The docs handle it in `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`, which receives notifications while the app is inactive, in the foreground, or in the background.

```swift
import UIKit

final class PushPayloadAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let sendbird = userInfo["sendbird"] as? [String: Any]
        let channelURL = (sendbird?["channel"] as? [String: Any])?["channel_url"] as? String
        if application.applicationState == .inactive {
            // Received while the app is inactive (the docs handle this state apart from
            // foreground and background). Before opening `channelURL`, initialize and connect.
        }
        _ = channelURL
        completionHandler(.newData)
    }
}
```

Chat calls made from this handler need a connection first; see "Call APIs only after connect completes" in knowledge/curated/ios/products/chat.md.

(source: https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/configuring-preferences/register-push-notification-credentials — Step 5 and the full `sendbird` payload format, reviewed 2026-10-11)

## Delivery receipts for offline members (Notification Service Extension)

A member who is offline receives the message only as an APNs push, so its delivery receipt is not updated unless your app marks it. Add a Notification Service Extension that links `SendbirdChatSDK` and call `SendbirdChat.markAsDelivered(remoteNotificationPayload:completionHandler:)` with the push payload; online members are then notified through `GroupChannelDelegate.channelDidUpdateDeliveryStatus(_:)`. `SendbirdChat.markPushNotificationAsDelivered(remoteNotificationPayload:completionHandler:)` is a different API — it reports push delivery tracking, and it needs `SendbirdChat.setAppGroup(_:)` in both the AppDelegate and the extension.

```swift
import UserNotifications
import SendbirdChatSDK

class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let userInfo = request.content.userInfo
        // Delivery receipt for the message carried by this push
        SendbirdChat.markAsDelivered(remoteNotificationPayload: userInfo) { error in }
        // Optional: push delivery tracking (also call setAppGroup in the app's AppDelegate)
        SendbirdChat.setAppGroup("APP_GROUP")
        SendbirdChat.markPushNotificationAsDelivered(remoteNotificationPayload: userInfo) { error in }
        contentHandler(request.content)
    }
}
```

(source: SendbirdChatSDK.swiftinterface (4.39.10) lines 6512, 6515, 6546, 2975; https://sendbird.com/docs/chat/sdk/v4/ios/message/marking-messages-as-delivered-in-a-group-channel/mark-messages-as-delivered; https://sendbird.com/docs/chat/sdk/v4/ios/push-notifications/marking-push-notifications-as-delivered/mark-push-notifications-as-delivered)

## VoIP (Calls)
VoIP push for Calls is registered through the Calls SDK, not Chat — use
`SendBirdCall.registerVoIPPush(token:unique:)` (see knowledge/curated/ios/products/calls.md).
The Chat SDK's PushKit registration method was removed.

## Setup checklist
- Enable Push Notifications + Background Modes (Remote notifications) capabilities.
- Upload the APNs auth key or certificate by following the official dashboard push configuration guide. Do not guess the current dashboard path.
- Register the token after connect; handle the payload in your notification delegate.

## Pitfalls
- Register only after the user is connected.
- `unique: true` removes all tokens previously registered for the user and keeps only this one; `unique: false` adds it alongside the others (see One token, one device, one signed-in user).
- On logout, unregister this device's token before `disconnect`; a disconnected user still receives push.
- Tokens/keys are secrets — never hard-code or log.

## Related
- Chat connect: knowledge/curated/ios/products/chat.md
- AI Agent push: see knowledge/curated/ios/products/ai-agent.md
