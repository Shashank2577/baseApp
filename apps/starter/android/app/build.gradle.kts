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

    signingConfigs {
        // The vendor's shared test key (baseApp signing/README.md): every build of
        // every app is signed alike, so sideloaded builds update in place and share
        // models. Public: never publish to a store with it.
        // The key file isn't committed (keys never are): put it at signing/showcase-test.jks
        // locally, or set the ANDROID_KEYSTORE_* secrets in CI. Without it, the debug key is used.
        create("vendorTest") {
            storeFile = rootProject.file("../../../signing/showcase-test.jks")
            storePassword = "phonedots-test"
            keyAlias = "phonedots-test"
            keyPassword = "phonedots-test"
        }
        // Your release key, from CI secrets (ANDROID_KEYSTORE_BASE64 and friends).
        System.getenv("ANDROID_KEYSTORE_PATH")?.let { keystore ->
            create("release") {
                storeFile = file(keystore)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        // Every app of the vendor must be signed with the SAME key: the
        // shared-model permission is signature-level.
        val vendor = signingConfigs.getByName("vendorTest").takeIf { it.storeFile?.exists() == true }
        debug {
            signingConfig = vendor ?: signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.findByName("release") ?: vendor ?: signingConfigs.getByName("debug")
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
