plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.showcase.starter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.showcase.starter"
        // 26: LiteRT-LM and java.time (base_ai_native). Keep every app on the same floor.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Shared model store (base_models). Must match platform.yaml -> sharedModels,
        // and be identical in every app of the vendor, or they stop sharing models.
        manifestPlaceholders["baseModelsPermission"] = "com.showcase.permission.SHARED_MODELS"
        manifestPlaceholders["baseModelsDiscoveryAction"] = "com.showcase.action.SHARED_MODELS"
    }

    buildTypes {
        release {
            // Every app of the vendor must be signed with the SAME release key: the
            // shared-model permission is signature-level. CI provides it (see the
            // release skill); local release builds fall back to the debug key.
            val keystore = System.getenv("ANDROID_KEYSTORE_PATH")
            signingConfig = if (keystore != null) {
                signingConfigs.create("release") {
                    storeFile = file(keystore)
                    storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                    keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                    keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
                }
            } else {
                signingConfigs.getByName("debug")
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
