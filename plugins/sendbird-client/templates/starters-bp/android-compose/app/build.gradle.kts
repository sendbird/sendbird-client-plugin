// source: knowledge/curated/android/setup.md ("Getting a newer Chat SDK under UIKit", "App ID in Gradle")
// source: knowledge/curated/android/hosts/compose.md ("UIKit for Jetpack Compose — init, then push")
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// BP02: the App ID comes from build configuration, first non-blank of: a Gradle property
// (-PSENDBIRD_APP_ID=..., ORG_GRADLE_PROJECT_SENDBIRD_APP_ID, or gradle.properties), the
// SENDBIRD_APP_ID environment variable, or local.properties. A missing value does not fail the
// build; the sign-in screen reports it.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}
val sendbirdAppId: String = listOf(
    project.findProperty("SENDBIRD_APP_ID") as String?,
    System.getenv("SENDBIRD_APP_ID"),
    localProperties.getProperty("SENDBIRD_APP_ID"),
).firstOrNull { !it.isNullOrBlank() }?.trim() ?: ""

android {
    namespace = "com.example.starterbp.compose"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.example.starterbp.compose"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "SENDBIRD_APP_ID", "\"$sendbirdAppId\"")
    }
    buildFeatures {
        buildConfig = true
        compose = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation("com.sendbird.sdk:uikit-compose:1.3.6")
    implementation("com.sendbird.sdk:sendbird-chat:4.36.5") // newer Chat SDK than the one UIKit declares
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.compose.ui:ui:1.9.2")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.navigation:navigation-compose:2.8.9")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
}
