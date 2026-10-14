// source: knowledge/curated/android/hosts/compose.md ("UIKit for Jetpack Compose — init, then push")
// source: knowledge/curated/android/cross-cutting/theme.md ("Jetpack Compose host")
package com.example.starterbp.compose

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.starterbp.compose.auth.LoginService
import com.example.starterbp.compose.sendbird.Connection
import com.example.starterbp.compose.sendbird.SendbirdSession
import com.example.starterbp.compose.sendbird.SessionState
import com.sendbird.uikit.compose.navigation.SendbirdNavigation
import com.sendbird.uikit.compose.navigation.sendbirdGroupChannelNavGraph
import com.sendbird.uikit.compose.theme.SendbirdTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // BP12: one theme for the app and the UIKit screens, set before any of them is drawn.
            SendbirdTheme(isDarkTheme = false) {
                Surface(
                    modifier = Modifier
                        .fillMaxSize()
                        .safeDrawingPadding()
                        .semantics { testTagsAsResourceId = true }, // BP17: test tags work as resource ids
                ) { StarterApp() }
            }
        }
    }
}

/** Sign-in screen while signed out, the home screen and UIKit screens otherwise (BP16). */
@Composable
fun StarterApp() {
    val state by SendbirdSession.state.collectAsStateWithLifecycle()
    when (val s = state) {
        is SessionState.SignedOut -> LoginScreen(s.notice)
        is SessionState.Connecting -> SignedInNavHost(s.userId, "Connecting…", ready = false)
        is SessionState.SignedIn -> SignedInNavHost(
            s.userId,
            when (s.connection) {
                Connection.CONNECTED -> "Connected"
                Connection.RECONNECTING -> "Reconnecting…"
                Connection.OFFLINE -> "Offline"
            },
            ready = true,
        )
    }
}

@Composable
private fun LoginScreen(notice: String?) {
    var userId by rememberSaveable { mutableStateOf("") }
    val canSignIn = SendbirdSession.appIdConfigured && userId.isNotBlank()
    // Your own sign-in goes here; on success:
    val signIn = { if (canSignIn) LoginService().onLoginSucceeded(userId.trim()) }
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Sign in", style = MaterialTheme.typography.headlineSmall)
        if (!SendbirdSession.appIdConfigured) {
            // BP02: a missing App ID is reported here instead of failing the build.
            Text(
                "No App ID configured. Set SENDBIRD_APP_ID in local.properties or gradle.properties and rebuild.",
                color = Color(0xFFB42318),
                modifier = Modifier.testTag("sb_app_id_missing"),
            )
        }
        OutlinedTextField(
            value = userId,
            onValueChange = { userId = it },
            label = { Text("User ID") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
            keyboardActions = KeyboardActions(onGo = { signIn() }),
            modifier = Modifier.fillMaxWidth().testTag("sb_login_user_id"),
        )
        Button(onClick = signIn, enabled = canSignIn, modifier = Modifier.fillMaxWidth().testTag("sb_login_button")) {
            Text("Sign in")
        }
        if (notice != null) Text(notice, color = Color(0xFFB42318))
    }
}

@Composable
private fun SignedInNavHost(userId: String, status: String, ready: Boolean) {
    val navController = rememberNavController()
    NavHost(navController = navController, startDestination = "home") {
        composable("home") { HomeScreen(userId, status, ready, navController) }
        // The UIKit screens: channel list -> conversation -> settings, members, invite.
        sendbirdGroupChannelNavGraph(navController)
    }
}

@Composable
private fun HomeScreen(userId: String, status: String, ready: Boolean, navController: NavController) {
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Signed in as $userId", style = MaterialTheme.typography.titleMedium)
        Text(status, modifier = Modifier.testTag("sb_connection_status"))
        if (ready) { // BP06: nothing that calls the server before connect returns
            Button(
                onClick = { navController.navigate(SendbirdNavigation.GroupChannel.route) },
                modifier = Modifier.fillMaxWidth().testTag("sb_open_channels"),
            ) { Text("Channels") }
        }
        OutlinedButton(
            onClick = { LoginService().onLogout() },
            modifier = Modifier.fillMaxWidth().testTag("sb_logout_button"),
        ) { Text("Sign out") }
    }
}
