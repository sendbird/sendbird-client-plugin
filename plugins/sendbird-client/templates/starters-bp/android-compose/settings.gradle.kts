// source: knowledge/curated/android/hosts/compose.md ("UIKit for Jetpack Compose — init, then push": same repository)
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
