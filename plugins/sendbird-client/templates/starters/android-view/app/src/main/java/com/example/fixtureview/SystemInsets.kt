package com.example.fixtureview

import android.app.Activity
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

// An app that targets API 35 is edge-to-edge on Android 15 devices, and the app must handle insets itself
// (https://developer.android.com/about/versions/15/behavior-changes-15). The keyboard is an inset too, read with
// WindowInsetsCompat.Type.ime() (https://developer.android.com/develop/ui/views/layout/sw-keyboard). Call this right
// after setContentView in every Activity of the app: the top bar then clears the status bar, and a message input at
// the bottom stays above the keyboard (2026-10-24: without it, a Chat SDK conversation screen on an API 35 emulator
// had its input behind the keyboard and its header under the status bar).
fun Activity.padForSystemBarsAndKeyboard() {
    val content = findViewById<View>(android.R.id.content)
    ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.ime())
        view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
        WindowInsetsCompat.CONSUMED
    }
}
