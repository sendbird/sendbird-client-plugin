// source: knowledge/curated/android/products/uikit.md ("Customization model (View host)", "Present prebuilt screens")
// source: https://github.com/sendbird/sendbird-uikit-android/blob/main/uikit/src/main/java/com/sendbird/uikit/fragments/ChannelListFragment.java#L286
package com.example.starterbp.view

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.starterbp.view.sendbird.SendbirdSession
import com.example.starterbp.view.sendbird.SessionState
import com.sendbird.uikit.fragments.ChannelListFragment
import kotlinx.coroutines.launch

/**
 * Hosts the UIKit channel list in a container with the stable id `sb_channel_list` (BP17).
 * Tapping a row opens UIKit's conversation screen (ChannelActivity).
 */
class ChannelListActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_channel_list)
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.sb_channel_list, ChannelListFragment.Builder().build())
                .commit()
        }
        // Leave the screen when the user signs out elsewhere.
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                SendbirdSession.state.collect { if (it is SessionState.SignedOut) finish() }
            }
        }
    }
}
