<!-- status: populated -->
# templates/android/view/chat

Chat init + connect + send on Android. Code from sendbird.com/docs (chat v4 android
getting-started, verified 2026-06-09); every import path verified against the public
samples `sendbird-chat-sample-android`. NOT
compiled in-repo (no Android/Java toolchain in the authoring env).

## Files
- `InitConnect.kt` — `ChatApplication` init + `connectUser(userId)` + `send(text, channel)`.

## How to splice
1. Gradle: maven `https://repo.sendbird.com/public/maven` in `settings.gradle`;
   `implementation("com.sendbird.sdk:sendbird-chat:4.36.3")` in `build.gradle`.
2. Set `ChatApplication` as `android:name` in `AndroidManifest.xml`.
3. Call `connectUser(...)` after login. App ID from BuildConfig/secret — never hard-code; tokens are secrets.

## Variations (see knowledge/curated/android/products/chat.md, all cited)
- Authenticated: `SendbirdChat.connect(userId, authToken) { user, e -> }`.
- Channels: load/create a `GroupChannel` before `send(...)`.
