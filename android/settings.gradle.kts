pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Generates the AppFunctions schema for Gemini (androidx.appfunctions compiler).
    id("com.google.devtools.ksp") version "2.3.13" apply false
}

include(":app")

// Gradle 9 requires writable project directories, including SDK dev plugins.
// Nix stores integration_test in an immutable SDK. Keep the dependency as an
// SDK dependency and use a local Android source copy for both run and drive.
findProject(":integration_test")?.let { plugin ->
    val source = plugin.projectDir
    if (source.absolutePath.startsWith("/nix/store/")) {
        require(source.isDirectory) { "Missing integration_test Android plugin: $source" }
        val sdkKey = java.security.MessageDigest.getInstance("SHA-256")
            .digest(source.canonicalPath.toByteArray())
            .joinToString("") { "%02x".format(it) }
            .take(16)
        val writableSource = file(".gradle/flutter-sdk-plugins/$sdkKey/integration_test")
        if (!writableSource.isDirectory) {
            source.copyRecursively(writableSource)
        }
        plugin.projectDir = writableSource
    }
}
