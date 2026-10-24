import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Firebase Cloud Messaging, applied only when this machine actually has a
 * Firebase project.
 *
 * `google-services.json` is git-ignored: it names a specific Firebase project,
 * and local, staging and production are three different ones. Applying the
 * plugin unconditionally would mean a fresh clone does not build at all —
 * the plugin fails the build with "File google-services.json is missing" —
 * which is a bad trade for a feature that is allowed to be absent.
 *
 * So: present, and Android push works. Absent, and the app builds, runs,
 * and has no push. `PushNotificationService` degrades to nothing on the Dart
 * side to match.
 *
 * Unlike iOS, Android genuinely needs this file rather than only the
 * `--dart-define`s. The reason is a timing one: when a push arrives at a
 * *terminated* app, the Firebase SDK's own `ContentProvider` initialises the
 * default app from the string resources this plugin generates, and that
 * happens before any Dart code — including `Firebase.initializeApp(options:)`
 * — has run. Without the file there is nothing for it to read.
 *
 * Download it from the Firebase console (Project settings → Your apps →
 * Android app with applicationId `shop.reem.app`) and drop it in
 * `android/app/`.
 */
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "ohara: android/app/google-services.json not found — push notifications " +
            "are disabled in this build. See lib/core/notifications/push_config.dart.",
    )
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
        "ohara: no release keystore configured (android/key.properties). " +
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

    // Pins one set of Firebase library versions across every Firebase
    // dependency the Flutter plugins pull in, so `firebase_core` and
    // `firebase_messaging` can never resolve to two versions of the same
    // transitive artifact — which fails at runtime rather than at build time,
    // with a NoSuchMethodError in a release build only.
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))
}
