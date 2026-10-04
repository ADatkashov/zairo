import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// MAPS_API_KEY — env var (CI/CD) takes priority; local.properties (already
// gitignored, same file that already holds sdk.dir) is the convenient local
// dev fallback so a developer doesn't have to export an env var in every
// new shell. Never committed either way.
val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { stream -> localProperties.load(stream) }
}
val mapsApiKey: String = System.getenv("MAPS_API_KEY") ?: localProperties.getProperty("MAPS_API_KEY") ?: ""

// Facebook Login (flutter_facebook_auth) — same env-var-first/
// local.properties-fallback pattern as mapsApiKey. See
// docs/authentication.md's "Provider configuration" section for where a
// real Facebook App ID/Client Token come from; empty defaults keep the
// build green with Facebook Login simply unusable until they're set.
val facebookAppId: String = System.getenv("FACEBOOK_APP_ID") ?: localProperties.getProperty("FACEBOOK_APP_ID") ?: ""
val facebookClientToken: String =
    System.getenv("FACEBOOK_CLIENT_TOKEN") ?: localProperties.getProperty("FACEBOOK_CLIENT_TOKEN") ?: ""

// Release signing — read from android/key.properties if present (created
// locally by a dev, or written by CI from GitHub Secrets; see
// docs/ci-cd.md's "Android release signing" section). Absent entirely,
// this falls back to the debug keystore below, exactly like before this
// file started supporting real signing — a checkout with no key.properties
// still builds and runs `flutter build apk --release` unchanged.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.zairo"
    // Use compileSdk 36; Platform 37 not available in CircleCI environment.
    // flutter_secure_storage works with 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zairo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Fills the com.google.android.geo.API_KEY manifest placeholder
        // (see AndroidManifest.xml) — see mapsApiKey above. Empty by
        // default: GoogleMapsRenderer is never selected on the Dart side
        // without a matching --dart-define=MAPS_API_KEY, so an empty
        // native key here is a safe default, not a broken build.
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
        manifestPlaceholders["facebookAppId"] = facebookAppId
        manifestPlaceholders["facebookClientToken"] = facebookClientToken
        // Must never be empty even when facebookAppId is (an empty
        // android:scheme in an intent-filter's <data> is invalid) — "fb"
        // alone is syntactically valid and simply matches no real redirect
        // until a real App ID is configured.
        manifestPlaceholders["fbLoginProtocolScheme"] = "fb$facebookAppId"
    }

    signingConfigs {
        // Committed, deterministic debug keystore (ci-debug.keystore — not
        // sensitive, same well-known "android"/"androiddebugkey"
        // credentials Android's own default debug key uses) so every
        // build shares one certificate. Without this, the Android Gradle
        // Plugin's default "debug" config falls back to
        // ~/.android/debug.keystore, silently auto-generated fresh by
        // every ephemeral CI runner — making each build-artifacts.yml run
        // sign with a different key, which Android then refuses to
        // install over whatever build a device already has (signature
        // mismatch) without uninstalling first.
        getByName("debug") {
            storeFile = file("ci-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real release signing when android/key.properties exists (see
            // docs/ci-cd.md); otherwise the debug keystore, so `flutter
            // build apk --release` / `flutter run --release` still work
            // with no setup, same as before release signing existed here.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
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
