// source: https://sendbird.com/docs/chat/uikit/v3/jetpack-compose/essentials/push-notifications
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { setUrl("https://repo.sendbird.com/public/maven") }
    }
}
rootProject.name = "sendbird-starter-bp-android-compose"
include(":app")
