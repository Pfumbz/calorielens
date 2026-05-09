plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.pcmacstudios.calorielens"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.pcmacstudios.calorielens"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("CM_KEYSTORE_PATH") ?: System.getenv("FCI_KEYSTORE_PATH")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: System.getenv("FCI_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS") ?: System.getenv("FCI_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD") ?: System.getenv("FCI_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val keystorePath = System.getenv("CM_KEYSTORE_PATH") ?: System.getenv("FCI_KEYSTORE_PATH")
            signingConfig = if (keystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
