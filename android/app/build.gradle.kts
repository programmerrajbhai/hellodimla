import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")

if (signingFile.exists()) {
    signingFile.inputStream().use {
        signingProperties.load(it)
    }
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseRequested) {
    require(signingFile.exists()) {
        "Release signing requires android/key.properties and your upload keystore."
    }

    listOf(
        "storeFile",
        "storePassword",
        "keyAlias",
        "keyPassword"
    ).forEach {
        require(!signingProperties.getProperty(it).isNullOrBlank()) {
            "Missing $it in android/key.properties"
        }
    }
}

android {
    namespace = "com.novatech.hellodimla"
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
        applicationId = "com.novatech.hellodimla"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
            storePassword = signingProperties.getProperty("storePassword")

            storeFile = signingProperties.getProperty("storeFile")?.let {
                rootProject.file(it)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}