import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The keystore and both passwords live OUTSIDE the repository;
// android/key.properties points at them, and android/.gitignore covers
// key.properties, **/*.jks and **/*.keystore.
//
// A missing key.properties is a hard failure on a release build, never a
// fallback. This project signed release builds with the Flutter template's
// debug keystore for months — a publicly known key, so anyone can forge an
// update for a build carrying it. A silent fallback would let that return
// without anyone noticing. test/platform_config_test.dart asserts the refusal.
//
// The refusal is scoped to release tasks on purpose: throwing unconditionally
// at configuration time would break `flutter run` for anyone without a
// keystore, which is not what this is protecting.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
} else if (gradle.startParameter.taskNames.any { it.contains("Release") }) {
    throw GradleException(
        "android/key.properties is missing, so this release build has no " +
        "upload keystore. Create it from the four keys in README, or build " +
        "in debug. Refusing to fall back to the debug signing config."
    )
}

android {
    namespace = "app.vitomy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications: without it the build fails
        // outright with "Dependency ':flutter_local_notifications' requires core
        // library desugaring to be enabled for :app" — a hard failure, not a
        // warning. Asserted by test/platform_config_test.dart so a Gradle
        // tidy-up cannot silently remove the phase's ability to build.
        // (Kotlin DSL spells the flag with an `is` prefix; the Groovy form
        // `coreLibraryDesugaringEnabled true` does not compile here.)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Reverse-DNS of the domain the project owns, vitomy.app. Permanent:
        // the Play Console and App Store Connect records are keyed on it.
        applicationId = "app.vitomy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
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

// The desugaring runtime that `isCoreLibraryDesugaringEnabled` above needs, at
// the version 07-RESEARCH §3.1 built a green debug AND release APK with.
// Deliberately NOT accompanied by `multiDexEnabled` — the plugin's README
// suggests it, both APKs built without it, and a speculative build flag is a
// thing nobody later dares remove.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
