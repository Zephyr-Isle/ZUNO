package com.zuno.wallpaper

import com.zuno.wallpaper.bridge.ZunoBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * 主 App 的 Flutter Activity。
 *
 * 架构上这里只做两件事：
 * 1. 承载 Flutter 管理端 UI（壁纸库 / 导入 / 预览 / 设置）；
 * 2. 在引擎启动后注册 Platform Channel（[ZunoBridge]），
 *    Dart 侧通过它把“当前激活壁纸 + 配置”写入原生 SharedPreferences。
 *
 * 注意：这里创建的 FlutterEngine 属于 Activity 生命周期。
 * 壁纸运行时（WallpaperService）需要长期存活的引擎时使用
 * [com.zuno.wallpaper.flutter.FlutterEngineHolder]，两者互不共享。
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ZunoBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
