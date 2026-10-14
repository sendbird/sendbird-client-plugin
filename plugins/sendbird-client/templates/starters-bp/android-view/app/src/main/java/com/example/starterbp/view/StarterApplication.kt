package com.example.starterbp.view

import android.app.Application
import com.example.starterbp.view.sendbird.SendbirdSession

class StarterApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // BP01: initialize Sendbird once, for the whole process.
        SendbirdSession.init(this)
    }
}
