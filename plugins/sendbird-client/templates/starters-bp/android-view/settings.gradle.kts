// source: knowledge/curated/android/setup.md ("Packaging (Gradle)")
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { setUrl("https://repo.sendbird.com/public/maven") }
    }
}
rootProject.name = "sendbird-starter-bp-android-view"
include(":app")
