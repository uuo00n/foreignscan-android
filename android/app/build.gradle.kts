import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置文件（位于 android/key.properties）
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

// 读取 local.properties，支持通过 opencv.sdk 指定 OpenCV Android SDK 路径
val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

val configuredOpenCvSdkPath =
    localProperties.getProperty("opencv.sdk")?.trim()?.takeIf { it.isNotEmpty() }

val openCvSdkCandidates =
    listOfNotNull(
        configuredOpenCvSdkPath,
        "${rootProject.projectDir.absolutePath}/third_party/OpenCV-android-sdk/sdk",
        "${rootProject.projectDir.parentFile.absolutePath}/third_party/OpenCV-android-sdk/sdk",
    )

val openCvSdkDir = openCvSdkCandidates.map(::file).firstOrNull { it.exists() }
val openCvSdkPath = openCvSdkDir?.absolutePath ?: ""

if (configuredOpenCvSdkPath != null && (openCvSdkDir == null || openCvSdkDir.absolutePath != file(configuredOpenCvSdkPath).absolutePath)) {
    throw GradleException(
        "Configured OpenCV SDK not found at: $configuredOpenCvSdkPath. " +
            "Please fix opencv.sdk in android/local.properties.",
    )
}

val openCvEnabled = openCvSdkDir != null
if (!openCvEnabled) {
    println(
        "WARNING: OpenCV SDK not found. Native ORB matching is disabled for this build. " +
            "Set opencv.sdk in android/local.properties or place SDK under " +
            "android/third_party/OpenCV-android-sdk/sdk.",
    )
}

android {
    namespace = "com.dnui.huangjunbo.foreignscan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dnui.huangjunbo.foreignscan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (openCvEnabled) {
            externalNativeBuild {
                cmake {
                    cppFlags += "-std=c++17"
                    cppFlags += "-O3"
                    arguments += "-DOpenCV_DIR=$openCvSdkPath/native/jni"
                }
            }
        }

        ndk {
            abiFilters += "arm64-v8a"
            abiFilters += "armeabi-v7a"
            abiFilters += "x86_64"
        }
    }

    // 签名配置：若存在 key.properties 则使用 release 签名，否则使用 debug 签名
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 若有 key.properties 配置则使用 release 签名，否则回退到 debug 签名
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    if (openCvEnabled) {
        sourceSets {
            getByName("main") {
                jniLibs.srcDirs("$openCvSdkPath/native/libs", "src/main/jniLibs")
            }
        }

        externalNativeBuild {
            cmake {
                path = file("src/main/cpp/CMakeLists.txt")
            }
        }
    }
}

flutter {
    source = "../.."
}
