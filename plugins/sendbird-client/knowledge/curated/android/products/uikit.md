<!-- last-verified-against: sendbird-uikit-android 3.26.3 -->
<!-- status: populated -->
# android uikit

> Verified against the public mirror `sendbird/sendbird-uikit-android` (uikit-samples BaseApplication, verified 2026-06-09). The templates compiled against 3.26.3 in GitHub Actions run 34187419379 on 2026-09-08. The "Present prebuilt screens" section below verified against the real `uikit-3.26.3.aar` (downloaded from `https://repo.sendbird.com/public/maven`, decompiled with `javap -public`, verified 2026-09-29). Cite each symbol; do not add API from memory.
> Primary source: https://github.com/sendbird/sendbird-uikit-android (docs: https://sendbird.com/docs/uikit/v3/android/overview)

## Overview
Sendbird UIKit gives prebuilt chat screens (channel list, channel, settings) on top of Chat. Initialize UIKit with an adapter that supplies the app ID + user info, then launch the provided fragments/activities.

## Install (Gradle)
- Repo in `settings.gradle`: `maven { setUrl("https://repo.sendbird.com/public/maven") }`.
- Dependency: `implementation("com.sendbird.sdk:uikit:3.26.3")` (or `3.+`).

## Initialize (Application class)
```kotlin
import com.sendbird.uikit.SendbirdUIKit
import com.sendbird.uikit.adapter.SendbirdUIKitAdapter
import com.sendbird.uikit.interfaces.UserInfo
import com.sendbird.android.handler.InitResultHandler
import com.sendbird.android.exception.SendbirdException

val adapter = object : SendbirdUIKitAdapter {
    override fun getAppId(): String = APP_ID
    override fun getAccessToken(): String? = null
    override fun getUserInfo(): UserInfo = object : UserInfo {
        override fun getUserId(): String = USER_ID
        override fun getNickname(): String = NICKNAME
        override fun getProfileUrl(): String = PROFILE_URL
    }
    override fun getInitResultHandler(): InitResultHandler = object : InitResultHandler {
        override fun onMigrationStarted() { }
        override fun onInitFailed(e: SendbirdException) { }
        override fun onInitSucceed() { }
    }
}
SendbirdUIKit.init(adapter, context)
```
(source: sendbird-uikit-android uikit-samples BaseApplication.kt)

## Present prebuilt screens
```kotlin
startActivity(ChannelListActivity.newIntent(this))

startActivity(ChannelActivity.newIntent(this, channelUrl))
```
`ChannelListActivity.newIntent(Context)` (and an overload taking a theme resource id) builds the channel-list screen's intent; `ChannelActivity.newIntent(Context, channelUrl: String)` opens a specific conversation. `ChannelListActivity.newRedirectToChannelIntent(Context, channelUrl)` opens the list and immediately redirects into that channel. (source: `sendbird-uikit-android` 3.26.3 AAR (`uikit-3.26.3.aar`), `javap` on `com.sendbird.uikit.activities.ChannelListActivity`, `com.sendbird.uikit.activities.ChannelActivity`)

## Theme + push (optional)
- `SendbirdUIKit.setDefaultThemeMode(...)` for light/dark.
- Push via `SendbirdPushHelper` (FCM). (source: sendbird-uikit-android uikit-samples BaseApplication.kt)

## Pitfalls
- Provide a non-null `getUserInfo().getUserId()`; UIKit needs the current user.
- App ID from BuildConfig/secret; access token is a secret — never hard-code.
- View-based — Compose apps host the fragments/activities via interop.

## Related
- Repo: https://github.com/sendbird/sendbird-uikit-android
- Overview docs: https://sendbird.com/docs/uikit/v3/android/overview
- Underlying Chat: knowledge/curated/android/products/chat.md
