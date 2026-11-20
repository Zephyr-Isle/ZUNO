import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名（可选）：在 android/key.properties 里配置 storeFile/storePassword/
// keyAlias/keyPassword。文件不存在时回退 debug 签名，保证 `flutter build apk
// --release` 在开发机上开箱即用；上架前务必配置正式密钥。
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.zuno.wallpaper"
    // 固定 37：permission_handler_android 14.x 等插件要求以 SDK 37 编译（向后兼容旧设备运行）。
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    // BuildConfig.DEBUG 用于日志卫生（release 关闭 chatty 日志）。
    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zuno.wallpaper"
        // ZUNO 的最低支持版本由产品要求固定为 24（Android 7.0），
        // 覆盖 flutter.minSdkVersion 的默认值，保证 WallpaperService / EGL14 / WebViewAssetLoader 行为一致。
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("zunoRelease") {
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // 上线标准：启用 R8 代码收缩与资源收缩（AOT Dart 代码不受影响；
            // 反射点已通过 proguard-rules.pro 显式保留）。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 配置了 key.properties → 正式签名；否则回退 debug 签名（仅本地验证用）。
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("zunoRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // 按 ABI 拆分：胖 APK 把三份 Flutter 引擎（arm64/v7a/x86_64 各 ~15MB）打包在一起。
    // 拆分后单 ABI 包约为胖包的 1/3（arm64 ≈ 20MB）；同时保留 universalApk，
    // 原有 `flutter build apk --release` 工作流不变（侧载/分发仍可用全量包）。
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
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

dependencies {
    // WebViewAssetLoader：为 HTML 壁纸提供 https://appassets.local/ 假源，禁用 file:// 访问。
    implementation("androidx.webkit:webkit:1.13.0")
    // WorkManager：驱动 timed 类型壁纸的“元调度器”（周期 >= 15 分钟，平台硬限制）。
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    // ExoPlayer：视频壁纸的原生播放管线。相比 MediaPlayer，它可以显式选择
    // 软/硬解码器（解码方式设置），并统一处理循环、倍速与 Surface 生命周期。
    // 版本与 video_player_android 使用的 media3 保持一致，避免重复类。
    implementation("androidx.media3:media3-exoplayer:1.9.2")
}
