// source: https://sendbird.com/docs/chat/sdk/v4/android/getting-started/send-first-message (verified 2026-06-09)
// Quoted verbatim from the official Android quickstart. NOT compiled in-repo (no Android toolchain).
// Gradle: settings.gradle -> maven { setUrl("https://repo.sendbird.com/public/maven") }
//         build.gradle  -> implementation("com.sendbird.sdk:sendbird-chat:4.36.3")
// App ID from BuildConfig/secret; session/access tokens are secrets — never hard-code.

import android.app.Application
import com.sendbird.android.SendbirdChat
import com.sendbird.android.exception.SendbirdException
import com.sendbird.android.handler.InitResultHandler
import com.sendbird.android.params.InitParams
import com.sendbird.android.params.UserMessageCreateParams
import com.sendbird.android.channel.GroupChannel

private const val APP_ID = "YOUR_SENDBIRD_APP_ID"

class ChatApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        SendbirdChat.init(
            InitParams(APP_ID, applicationContext, useCaching = true),
            object : InitResultHandler {
                override fun onMigrationStarted() { }
                override fun onInitFailed(e: SendbirdException) { }
                override fun onInitSucceed() {
                    // Ready — connect a user here or after login.
                }
            }
        )
    }
}

// Connect after init. Authenticated apps: SendbirdChat.connect(userId, authToken) { user, e -> ... }
fun connectUser(userId: String) {
    SendbirdChat.connect(userId) { user, e ->
        if (user != null) { /* connected */ }
    }
}

// Send a text message to an already-loaded GroupChannel.
fun send(text: String, channel: GroupChannel) {
    channel.sendUserMessage(UserMessageCreateParams(text)) { _, e ->
        if (e != null) { /* handle error */ }
    }
}
