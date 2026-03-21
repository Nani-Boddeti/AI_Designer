import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val keystorePath = System.getenv("KEYSTORE_PATH")
    ?: keystoreProperties.getProperty("KEYSTORE_PATH")
val storePasswordValue = System.getenv("STORE_PASSWORD")
    ?: keystoreProperties.getProperty("STORE_PASSWORD")
val keyAliasValue = System.getenv("KEY_ALIAS")
    ?: keystoreProperties.getProperty("KEY_ALIAS")
val keyPasswordValue = System.getenv("KEY_PASSWORD")
    ?: keystoreProperties.getProperty("KEY_PASSWORD")

val hasReleaseSigning = !keystorePath.isNullOrBlank() &&
    !storePasswordValue.isNullOrBlank() &&
    !keyAliasValue.isNullOrBlank() &&
    !keyPasswordValue.isNullOrBlank() &&
    keystorePath?.let { rootProject.file(it).exists() } == true

android {
    namespace = "com.aidesigner.ai_designer_assist"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.aidesigner.ai_designer_assist"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = rootProject.file(keystorePath!!)
                storePassword = storePasswordValue!!
                keyAlias = keyAliasValue!!
                keyPassword = keyPasswordValue!!
            }
        }
    }

    buildTypes {
        release {
            // Uses release keystore from env vars or android/key.properties.
            // Falls back to debug signing when any release signing input is missing.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
