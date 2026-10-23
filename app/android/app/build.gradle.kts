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
            keyAlias = System.getenv("ALIAS") ?: keystoreProperties["keyAlias"] as String?
            keyPassword = System.getenv("PASS") ?: keystoreProperties["keyPassword"] as String?
            storeFile = file("../keystore/keystore.jks")
            storePassword = System.getenv("PASS") ?: keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
    implementation("androidx.work:work-runtime-ktx:2.10.5")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
