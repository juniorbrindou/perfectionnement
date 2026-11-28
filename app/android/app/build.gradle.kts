import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de publication : android/key.properties (non versionné) avec storeFile, storePassword,
// keyAlias, keyPassword. Sans lui, la release est une version β qui s'installe à côté du jeu publié.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val publication = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.juniorbrindou.perfectionnement"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Même identifiant que la version Godot : la version publiée s'installera par-dessus.
        applicationId = "com.juniorbrindou.perfectionnement"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (publication) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Pendant la réécriture, la version de test s'installe à côté du jeu Godot, sans le remplacer.
        debug {
            applicationIdSuffix = ".flutter"
            resValue("string", "app_name", "Perfectionnement β")
        }
        release {
            if (publication) {
                resValue("string", "app_name", "Perfectionnement")
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Signature de test : identifiant distinct pour ne jamais gêner le jeu publié.
                applicationIdSuffix = ".flutter"
                resValue("string", "app_name", "Perfectionnement β")
                signingConfig = signingConfigs.getByName("debug")
            }
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
