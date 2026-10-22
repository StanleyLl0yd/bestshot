import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}
// Optional CI signing; no credentials in VCS. Without all credentials release is unsigned.
val requiredSigningVars = listOf(
    "BESTSHOT_SIGNING_STORE_FILE",
    "BESTSHOT_SIGNING_STORE_PASSWORD",
    "BESTSHOT_SIGNING_KEY_ALIAS",
    "BESTSHOT_SIGNING_KEY_PASSWORD"
)
val signingVars = requiredSigningVars.associateWith { providers.environmentVariable(it).orNull }
val signingRequested = signingVars.values.any { !it.isNullOrEmpty() }
if (signingRequested) {
    require(signingVars.values.all { !it.isNullOrEmpty() }) {
        "Incomplete release signing environment: all four BESTSHOT_SIGNING_* values required"
    }
}

android {
    namespace = "com.sl.bestshot"
    compileSdk = 37
    compileSdkMinor = 0 // API 37 is published as android-37.0
    defaultConfig {
        applicationId = "com.sl.bestshot"
        minSdk = 29
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        if (signingRequested) {
            create("bestshotRelease") {
                storeFile = file(signingVars.getValue("BESTSHOT_SIGNING_STORE_FILE")!!)
                storePassword = signingVars.getValue("BESTSHOT_SIGNING_STORE_PASSWORD")
                keyAlias = signingVars.getValue("BESTSHOT_SIGNING_KEY_ALIAS")
                keyPassword = signingVars.getValue("BESTSHOT_SIGNING_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (signingRequested) {
                signingConfig = signingConfigs.getByName("bestshotRelease")
            }
        }
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions { unitTests.isReturnDefaultValues = true }
}
kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }
dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.11.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0")
    implementation("androidx.documentfile:documentfile:1.1.0")
    implementation("com.google.mlkit:face-detection:16.1.7")
    testImplementation("junit:junit:4.13.2")
}
