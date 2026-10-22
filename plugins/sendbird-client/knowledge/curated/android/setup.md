<!-- last-verified-against: sendbird-chat-sdk-android 4.36.5 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-android -->
<!-- status: populated -->
# android — setup

> Coordinates checked against public Maven metadata and the local pinned/latest Android template compile on 2026-09-22. Cite each coordinate; do not invent versions.

> A plugin run does not build, compile, or type-check the project: do not run Gradle build tasks (such as `./gradlew assembleDebug`) or look for a JDK or Android SDK to build with unless the customer asks for a build (`docs/AGENT_CONTRACT.md` section 3). The compile above is the plugin's own test.

## Packaging (Gradle)
- Repo in `settings.gradle`: `maven { setUrl("https://repo.sendbird.com/public/maven") }`.
- Dependencies (pick what you need):
  - Chat: `implementation("com.sendbird.sdk:sendbird-chat:4.36.5")`
  - UIKit: `implementation("com.sendbird.sdk:uikit:3.26.3")`
  - AI Agent: `implementation("com.sendbird.sdk:ai-agent-messenger:1.19.1")`
  - Calls: `implementation 'com.sendbird.sdk:sendbird-calls:1.12.5'`
  - Desk: `implementation 'com.sendbird.sdk:sendbird-desk-android-sdk:1.2.0'`
  - Live: `implementation 'com.sendbird.sdk:sendbird-live:1.2.8'`
- UIKit/AI Agent need `buildFeatures { viewBinding = true }`, Java 11, API 21+.

## Getting a newer Chat SDK under UIKit

UIKit pins the Chat SDK it was built with (for example, `uikit:3.26.3` declares `sendbird-chat:4.36.4` in its POM). To run a newer Chat SDK, declare it explicitly in the app module; Gradle's default conflict resolution picks the highest requested version, so `sendbird-chat:4.36.4` resolves to `4.36.5`. Run `./gradlew :app:dependencies` to confirm the resolved version.

```kotlin
dependencies {
    implementation("com.sendbird.sdk:uikit:3.26.3")
    implementation("com.sendbird.sdk:sendbird-chat:4.36.5") // overrides the Chat SDK version UIKit declares
}
```

(source: https://repo.sendbird.com/public/maven/com/sendbird/sdk/uikit/3.26.3/uikit-3.26.3.pom; https://docs.gradle.org/current/userguide/graph_resolution.html)

## App ID in Gradle
The App ID is not a secret, so a fresh clone and CI should build without extra setup. Put it in `gradle.properties` (`SENDBIRD_APP_ID=...`), let `-PSENDBIRD_APP_ID=...` or an environment variable override it, and pass it on with `buildConfigField`. Do not throw from the build script when it is missing: an exception there fails every build, including CI and a teammate's first checkout. Check for an empty value at init time instead.

## Init
- Initialize once in `Application.onCreate` (Chat: `SendbirdChat.init`; UIKit: `SendbirdUIKit.init(adapter, context)`; AI Agent: `AIAgentMessenger.initialize(...)`).
- Register your `Application` in `AndroidManifest.xml`.

## DNS fallback (4.19.2+)

If the system DNS lookup fails on some networks, set `InitParams.useDnsFallback = true`: the SDK then retries the lookup once using a public DNS. It defaults to `false` and was added in Chat SDK 4.19.2.

```kotlin
val params = InitParams(APP_ID, applicationContext, useCaching = true).apply {
    useDnsFallback = true
}
SendbirdChat.init(params, initResultHandler)
```

(source: sendbird-chat-4.36.5.aar javap com.sendbird.android.params.InitParams; sendbird/sendbird-chat-sdk-android CHANGELOG.md v4.19.2)

## Pitfalls
- App ID from BuildConfig/secret; tokens are secrets.
- One App ID per app run. The authentication docs say the initialization method "must be called once across your client app", and they describe no way to switch to another App ID at runtime; keep development and production App IDs in separate build types or flavors. (source: https://sendbird.com/docs/chat/sdk/v4/android/application/authenticating-a-user/authentication)
  - When the customer asks to switch App IDs inside the app (a settings switch, a debug menu), do not build a runtime switch. Say why (the rule above), give each build type (debug and release) or flavor its own `SENDBIRD_APP_ID` value in the app's Gradle build file, passed on the way "App ID in Gradle" above describes, and finish the run with that change instead of asking or declining. A value the customer did not give stays empty and goes under the run's manual steps.
- Match Chat/UIKit min versions required by AI Agent (see products/ai-agent.md).

## Related
- Chat: knowledge/curated/android/products/chat.md
- Detection: tools/detection/android/
