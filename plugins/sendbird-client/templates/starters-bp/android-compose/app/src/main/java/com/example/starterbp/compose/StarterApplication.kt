package com.example.starterbp.compose

import android.app.Application
import com.example.starterbp.compose.sendbird.SendbirdSession

class StarterApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // BP01: initialize Sendbird once, for the whole process.
        SendbirdSession.init(this)
    }
}
