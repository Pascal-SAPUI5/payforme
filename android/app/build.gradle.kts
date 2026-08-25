plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.compose")
}

android {
    namespace = "de.wachowski.divido"
    compileSdk = 35

    defaultConfig {
        // Must match the package name reserved in the Play Console. It cannot
        // be changed after the first upload and stays reserved forever.
        applicationId = "de.wachowski.divido"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    // The upload key signs the bundle before it goes to Google. Play App
    // Signing then re-signs it with the key Google holds, which is what ends up
    // on devices — so losing this one is recoverable, unlike the old model.
    //
    // Everything comes from the environment: a keystore or its password in the
    // repository would be a credential leak with a git history.
    signingConfigs {
        create("release") {
            val keystore = System.getenv("DIVIDO_KEYSTORE_PATH")
            if (keystore != null) {
                storeFile = file(keystore)
                storePassword = System.getenv("DIVIDO_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("DIVIDO_KEY_ALIAS") ?: "divido-upload"
                keyPassword = System.getenv("DIVIDO_KEY_PASSWORD")
                    ?: System.getenv("DIVIDO_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Unsigned when no keystore is configured, so a plain `gradle build`
            // works on any machine without secrets.
            signingConfig = if (System.getenv("DIVIDO_KEYSTORE_PATH") != null) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin { jvmToolchain(17) }

    buildFeatures { compose = true }
}

dependencies {
    implementation(project(":core"))

    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("io.ktor:ktor-client-okhttp:2.3.12")
}
