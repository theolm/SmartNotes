import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.theolm.smartnotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13113456"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Device tests use a separate package so Flutter cannot remove journal data.
        applicationId = providers.gradleProperty("smartnotesApplicationId")
            .getOrElse("dev.theolm.smartnotes")
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // CI uses the KEY_* variables; ALIAS/PASS keep existing local scripts working.
            keyAlias = System.getenv("KEY_ALIAS")
                ?: System.getenv("ALIAS")
                ?: keystoreProperties["keyAlias"] as String?
            keyPassword = System.getenv("KEY_PASSWORD")
                ?: System.getenv("PASS")
                ?: keystoreProperties["keyPassword"] as String?
            // Optional override; relative paths resolve from app/android/app.
            storeFile = System.getenv("KEYSTORE_FILE")?.takeIf { it.isNotBlank() }?.let { file(it) }
                ?: (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                ?: file("../keystore/keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
                ?: System.getenv("PASS")
                ?: keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles("proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.12.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
