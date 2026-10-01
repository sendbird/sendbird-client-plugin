// source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/navigation (verified 2026-09-30)
// source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/authentication (verified 2026-09-30)
// source: https://github.com/sendbird/sendbird-uikit-sample-android-jetpack-compose/blob/main/uikit-compose-sample/src/main/java/com/sendbird/uikit/compose/sample/SendbirdUikitApp.kt (verified 2026-09-30)
// Symbols verified via javap of the published uikit-compose 1.3.6 AAR and its uikit-data 1.3.6
// dependency (2026-09-30):
//   - SendbirdUikitCompose.prepare(UikitCurrentUserInfo) / suspend connect()   (com.sendbird.uikit.compose)
//   - UikitCurrentUserInfo(userId, authToken = default)                          (com.sendbird.uikit.core.data.model)
//   - NavGraphBuilder.sendbirdGroupChannelNavGraph(navController, ...)           (com.sendbird.uikit.compose.navigation)
//   - SendbirdNavigation.GroupChannel.route, NavController.navigateToChannel(url) (com.sendbird.uikit.compose.navigation)
//   - SendbirdTheme { }                                                          (com.sendbird.uikit.compose.theme)
// UikitComposeApplication must have run SendbirdUikitCompose.init(...) first.
// Tokens are secrets — fetch them from your server; never hard-code or log them.

package com.sendbird.client.templatecheck.compose.uikit

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.navigation.NavController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.rememberNavController
import com.sendbird.uikit.compose.SendbirdUikitCompose
import com.sendbird.uikit.compose.navigation.SendbirdNavigation
import com.sendbird.uikit.compose.navigation.navigateToChannel
import com.sendbird.uikit.compose.navigation.sendbirdGroupChannelNavGraph
import com.sendbird.uikit.compose.theme.SendbirdTheme
import com.sendbird.uikit.core.data.model.UikitCurrentUserInfo

class UikitComposeActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SendbirdTheme {
                SendbirdChatApp(userId = "YOUR_USER_ID")
            }
        }
    }
}

/** Sets the current user, connects, and hosts the UIKit group-channel screens
 *  (channel list -> channel -> settings/members/invite) inside your NavHost. */
@Composable
fun SendbirdChatApp(userId: String) {
    val navController = rememberNavController()
    LaunchedEffect(userId) {
        // Authenticated apps: UikitCurrentUserInfo(userId = userId, authToken = token).
        SendbirdUikitCompose.prepare(UikitCurrentUserInfo(userId = userId))
        runCatching { SendbirdUikitCompose.connect() }
            .onFailure { /* connect failed — show an error / retry */ }
    }
    NavHost(
        navController = navController,
        startDestination = SendbirdNavigation.GroupChannel.route,
    ) {
        // Add your own composable(...) routes next to the Sendbird nested graph.
        sendbirdGroupChannelNavGraph(navController)
    }
}

/** Open one channel directly, e.g. from a push notification's channel URL. */
fun openSendbirdChannel(navController: NavController, channelUrl: String) {
    navController.navigateToChannel(channelUrl)
}
