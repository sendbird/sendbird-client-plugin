package com.example.starterbp.view

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.inputmethod.EditorInfo
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.doAfterTextChanged
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.starterbp.view.auth.LoginService
import com.example.starterbp.view.databinding.ActivityMainBinding
import com.example.starterbp.view.sendbird.Connection
import com.example.starterbp.view.sendbird.SendbirdSession
import com.example.starterbp.view.sendbird.SessionState
import kotlinx.coroutines.launch

/** Sign-in screen while signed out, home screen otherwise. It follows the app-wide session (BP16). */
class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // BP02: a missing App ID is reported here instead of failing the build.
        binding.sbAppIdMissing.visibility = if (SendbirdSession.appIdConfigured) View.GONE else View.VISIBLE
        binding.sbLoginUserId.doAfterTextChanged { updateSignInButton() }
        binding.sbLoginUserId.setOnEditorActionListener { _, actionId, _ ->
            (actionId == EditorInfo.IME_ACTION_GO).also { if (it) signIn() }
        }
        binding.sbLoginButton.setOnClickListener { signIn() }
        binding.sbOpenChannels.setOnClickListener {
            startActivity(Intent(this, ChannelListActivity::class.java))
        }
        binding.sbLogoutButton.setOnClickListener { LoginService().onLogout() }
        updateSignInButton()

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                SendbirdSession.state.collect { render(it) }
            }
        }
    }

    private fun signIn() {
        val userId = binding.sbLoginUserId.text.toString().trim()
        if (userId.isEmpty() || !SendbirdSession.appIdConfigured) return
        // Your own sign-in goes here; on success:
        LoginService().onLoginSucceeded(userId)
    }

    private fun updateSignInButton() {
        binding.sbLoginButton.isEnabled =
            SendbirdSession.appIdConfigured && binding.sbLoginUserId.text.isNotBlank()
    }

    private fun render(state: SessionState) {
        binding.login.visibility = if (state is SessionState.SignedOut) View.VISIBLE else View.GONE
        binding.home.visibility = if (state is SessionState.SignedOut) View.GONE else View.VISIBLE
        when (state) {
            is SessionState.SignedOut -> binding.notice.text = state.notice.orEmpty()
            is SessionState.Connecting -> {
                binding.user.text = "Signed in as ${state.userId}"
                binding.sbConnectionStatus.text = "Connecting…"
                binding.sbOpenChannels.visibility = View.GONE // BP06: nothing that calls the server before connect returns
            }
            is SessionState.SignedIn -> {
                binding.user.text = "Signed in as ${state.userId}"
                binding.sbConnectionStatus.text = when (state.connection) {
                    Connection.CONNECTED -> "Connected"
                    Connection.RECONNECTING -> "Reconnecting…"
                    Connection.OFFLINE -> "Offline"
                }
                binding.sbOpenChannels.visibility = View.VISIBLE
            }
        }
    }
}
