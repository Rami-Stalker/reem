import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing material, kept out of the repository.
 *
 * `android/key.properties` holds the keystore path and its three secrets; it is
 * git-ignored, as is every `*.jks`/`*.keystore`. A machine that has not been
 * given the keystore — a fresh clone, a contributor's laptop — simply has no
 * such file, and the build below falls back to the debug key so that
 * `flutter run --release` keeps working. Only a machine holding the real
 * keystore can produce an artifact the Play Store will accept as an update.
 *
 * See `android/key.properties.example` for the expected keys.
 */
val keystoreProperties =
    Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) {
            file.inputStream().use { load(it) }
        }
    }

/** The path is read relative to `android/`, unless it is already absolute. */
val releaseKeystoreFile =
    keystoreProperties.getProperty("storeFile")?.trim()?.takeIf { it.isNotEmpty() }?.let { path ->
        val candidate = File(path)
        if (candidate.isAbsolute) candidate else rootProject.file(path)
    }

val hasReleaseKeystore = releaseKeystoreFile?.exists() == true

if (!hasReleaseKeystore) {
    logger.warn(
        "reem: no release keystore configured (android/key.properties). " +
            "Release builds will be signed with the DEBUG key and cannot be " +
            "published. See android/key.properties.example.",
    )
}

android {
    namespace = "shop.reem.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent once the first build reaches the Play Store: an app's
        // identity there is its applicationId, and it cannot be changed.
        applicationId = "shop.reem.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }

            // R8. Flutter leaves both off by default, so a release bundle
            // shipped every unused class and every unreferenced drawable in
            // every dependency — tens of megabytes a woman on a Syrian mobile
            // plan pays for. `proguard-rules.pro` holds the keeps for the
            // plugins that reach their own code reflectively.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // A bundle Play can serve per-device rather than one universal APK.
    bundle {
        language { enableSplit = false } // Arabic and English ship together:
        // the in-app language switcher must work without a Play delivery.
        density { enableSplit = true }
        abi { enableSplit = true }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
