<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verification-method: derived-from-linked-curated -->
<!-- status: populated -->
# android — pitfalls

> Common Android integration mistakes. Conceptual guidance; any API named is cited in the linked product docs, except the "Messages (file send / resend)" section, which carries its own citation and was compiled against chat 4.36.5. Verified 2026-09-30.

## Setup
- Initialize Chat once in `Application.onCreate`; register `Application` in the manifest.
- UIKit/AI Agent are View-based (ViewBinding/Fragments) — the `MessengerLauncher` context must be a `FragmentActivity` (see ai-agent.md).
- Enable `buildFeatures { viewBinding = true }` for UIKit/AI Agent.

## Auth
- Call `SendbirdChat.setSessionHandler(...)` before `connect` (see auth.md).
- Tokens are secrets — read from BuildConfig/secret store, never hard-code.

## Lifecycle
- Remove channel handlers you add, bound to the Activity/Fragment lifecycle (see performance.md).
- Desk/AI Agent init only after Chat `onInitSucceed()`.

## Messages (file send / resend)

- With a `MessageCollection`, drive the pending → sent/failed UI from `onMessagesUpdated`, switching on `context.messagesSendingStatus` (`SUCCEEDED`, `FAILED`, `PENDING`, `CANCELED`) — that callback fires when a pending message's send status changes.
- Resend a failed file message with `channel.resendMessage(failedFileMessage) { message, e -> }` after checking `failedFileMessage.isResendable`. The `resendFileMessage(FileMessage, File, ...)` and `resendMessage(FileMessage, File, ...)` overloads are deprecated because the SDK keeps the original file object set when the message was sent.

```kotlin
override fun onMessagesUpdated(context: MessageContext, channel: GroupChannel, messages: List<BaseMessage>) {
    when (context.messagesSendingStatus) {
        SendingStatus.SUCCEEDED -> { /* pending -> sent */ }
        SendingStatus.FAILED -> { /* pending -> failed: offer retry */ }
        else -> {}
    }
}

fun resend(channel: GroupChannel, failed: FileMessage) {
    if (!failed.isResendable) return
    channel.resendMessage(failed) { message, e -> /* e != null -> still failed */ }
}
```

(source: sendbird-chat-4.36.5.aar javap com.sendbird.android.handler.BaseMessageCollectionHandler / com.sendbird.android.message.SendingStatus / javap -v com.sendbird.android.channel.BaseChannel (@Deprecated on resendFileMessage); https://sendbird.com/docs/chat/sdk/v4/android/local-caching/using-message-collection/message-collection)

## Push
- Register the FCM handler after init; declare the messaging service in the manifest (see push.md).

## Related
- Setup: knowledge/curated/android/setup.md
- Performance: knowledge/curated/android/cross-cutting/performance.md
