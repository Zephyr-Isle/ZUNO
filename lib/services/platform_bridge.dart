import 'package:flutter/services.dart';

/// Dart ↔ 原生 的 Platform Channel 封装（"zuno/native"，与 ZunoBridge.kt 对应）。
///
/// 所有影响壁纸运行时的状态（激活壁纸 / 性能档位）一律写向原生，
/// 由原生写入 SharedPreferences —— 这是引擎读取的唯一事实来源。
/// Flutter 的 shared_preferences 插件用的是独立 prefs 文件 + 前缀 key，
/// 原生引擎直接读它脆弱且不可控，所以这里不引入 shared_preferences。
class ZunoNative {
  ZunoNative._();

  static const MethodChannel _channel = MethodChannel('zuno/native');

  static Future<int> deviceApiLevel() async {
    try {
      final v = await _channel.invokeMethod<int>('deviceApiLevel');
      return v ?? 24;
    } on PlatformException {
      return 24;
    }
  }

  /// 写入“当前激活壁纸”。timed 类型应传入已解析的 slot 信息（[dir]/[entry]/[id]
  /// 为 slot 子包的对应值），[timedParentDir] 指向 timed 父包根目录。
  static Future<void> setActiveWallpaper({
    required String id,
    required String type,
    required String dir,
    required String entry,
    required String configJson,
    required String capabilitiesJson,
    String? timedParentDir,
  }) async {
    await _channel.invokeMethod<void>('setActiveWallpaper', {
      'id': id,
      'type': type,
      'dir': dir,
      'entry': entry,
      'configJson': configJson,
      'capabilitiesJson': capabilitiesJson,
      'timedParentDir': timedParentDir,
    });
  }

  static Future<Map<String, dynamic>?> getActiveWallpaper() async {
    final v = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getActiveWallpaper',
    );
    return v?.cast<String, Object?>();
  }

  /// 打开系统动态壁纸预览页（用户点“设置壁纸”确认后生效）。
  static Future<bool> launchWallpaperPreview() async {
    final v = await _channel.invokeMethod<bool>('launchWallpaperPreview');
    return v ?? false;
  }

  static Future<bool> isLiveWallpaperActive() async {
    final v = await _channel.invokeMethod<bool>('isLiveWallpaperActive');
    return v ?? false;
  }

  static Future<void> setPerformanceTier(String tier) =>
      _channel.invokeMethod<void>('setPerformanceTier', {'tier': tier});

  static Future<String> getPerformanceTier() async {
    final v = await _channel.invokeMethod<String>('getPerformanceTier');
    return v ?? 'medium';
  }

  /// 应用外观：system | light | dark（默认跟随系统）。
  static Future<String> getThemeMode() async {
    try {
      final v = await _channel.invokeMethod<String>('getThemeMode');
      return v ?? 'system';
    } on PlatformException {
      return 'system';
    }
  }

  static Future<void> setThemeMode(String mode) =>
      _channel.invokeMethod<void>('setThemeMode', {'mode': mode});

  /// 视频解码方式：auto | hardware | software（原生 zuno_config 持久化）。
  static Future<String> getVideoDecodeMode() async {
    try {
      final v = await _channel.invokeMethod<String>('getVideoDecodeMode');
      return v == 'hardware' || v == 'software' ? v! : 'auto';
    } on PlatformException {
      return 'auto';
    }
  }

  static Future<void> setVideoDecodeMode(String mode) =>
      _channel.invokeMethod<void>('setVideoDecodeMode', {'mode': mode});

  /// 解码失败时是否弹出“切换软解”提示（默认开启）。
  static Future<bool> getVideoDecodePrompt() async {
    try {
      final v = await _channel.invokeMethod<bool>('getVideoDecodePrompt');
      return v ?? true;
    } on PlatformException {
      return true;
    }
  }

  static Future<void> setVideoDecodePrompt(bool enabled) =>
      _channel.invokeMethod<void>('setVideoDecodePrompt', {'enabled': enabled});

  /// 最近一次视频解码失败（entryId/message/at/mode）；没有或已关闭提示时返回 null。
  static Future<Map<String, dynamic>?> getVideoDecodeFailure() async {
    try {
      final v = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getVideoDecodeFailure',
      );
      return v?.cast<String, Object?>();
    } on PlatformException {
      return null;
    }
  }

  static Future<void> clearVideoDecodeFailure() =>
      _channel.invokeMethod<void>('clearVideoDecodeFailure');

  /// 深度视差全局强度倍率（0.6 / 1.0 / 1.4）。
  static Future<double> getDepthStrengthScale() async {
    try {
      final v = await _channel.invokeMethod<double>('getDepthStrengthScale');
      return v ?? 1.0;
    } on PlatformException {
      return 1.0;
    }
  }

  static Future<void> setDepthStrengthScale(double scale) =>
      _channel.invokeMethod<void>('setDepthStrengthScale', {'scale': scale});

  /// 解析 timed 包在指定时刻应激活的 slot。
  /// [hour]/[minute] 为预览模式（滑杆拖动），缺省 = 设备当前时间。
  /// 预览模式绕过充电约束（用户手动选择时段）。
  static Future<Map<String, dynamic>?> resolveTimedSlot(
    String packageDir, {
    int? hour,
    int? minute,
  }) async {
    final v = await _channel.invokeMethod<Map<Object?, Object?>>(
      'resolveTimedSlot',
      {'dir': packageDir, 'hour': ?hour, 'minute': ?minute},
    );
    return v?.cast<String, Object?>();
  }

  /// 用原生沙箱 WebView 打开 HTML 壁纸预览（与壁纸渲染共用同一套沙箱实现）。
  static Future<void> openHtmlPreview({
    required String dir,
    required String entry,
    required String configJson,
  }) => _channel.invokeMethod<void>('openHtmlPreview', {
    'dir': dir,
    'entry': entry,
    'configJson': configJson,
  });

  static Future<bool> isIgnoringBatteryOptimizations() async {
    final v = await _channel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return v ?? false;
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    final v = await _channel.invokeMethod<bool>(
      'requestIgnoreBatteryOptimizations',
    );
    return v ?? false;
  }

  /// 为 HTML 包生成离屏截图缩略图（原生沙箱 WebView 真实渲染页面后截图，
  /// 与壁纸渲染同一套实现）。失败/超时返回 null（UI 显示占位图标）。
  static Future<String?> ensureHtmlThumbnail({
    required String dir,
    required String entryPath,
    required String outPath,
  }) async {
    try {
      return await _channel.invokeMethod<String>('ensureHtmlThumbnail', {
        'dir': dir,
        'entry': entryPath,
        'outPath': outPath,
      });
    } on PlatformException {
      return null;
    }
  }

  /// 导出分享：path 为已打包的 .zuno 文件（cache/exports/ 下），
  /// 经 FileProvider 临时授权拉起系统分享面板。
  static Future<bool> sharePackage({
    required String path,
    required String title,
  }) async {
    try {
      final v = await _channel.invokeMethod<bool>('sharePackage', {
        'path': path,
        'title': title,
      });
      return v ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 探测视频轨道编码（video/avc、video/hevc、video/av01…）。
  /// 详情页预览与壁纸引擎都走 ExoPlayer；壁纸引擎默认硬解、可切软解——
  /// 规格支持列表（H.264/H.265）之外的编码在此给出导入期提醒。
  static Future<String?> probeVideoCodec({required String path}) async {
    try {
      return await _channel.invokeMethod<String>('probeVideoCodec', {
        'path': path,
      });
    } on PlatformException {
      return null;
    }
  }

  /// 本机解码器能否实时解码该视频（profile/level/分辨率/帧率组合判定）。
  /// 4K60 H.264 High 5.2 等超限格式在 ExoPlayer 上报 NO_EXCEEDS_CAPABILITIES。
  static Future<bool?> probeVideoSupported({required String path}) async {
    try {
      return await _channel.invokeMethod<bool>('probeVideoSupported', {
        'path': path,
      });
    } on PlatformException {
      return null;
    }
  }

  // ------------------------------------------------------------ 壁纸库地址
  //
  // 存在原生 `zuno_config`（`library.base_url`）：和性能档位、外观一样属于
  // 应用级设置，不需要单独的存储文件。

  static Future<String?> getLibraryUrl() async {
    try {
      return await _channel.invokeMethod<String>('getLibraryUrl');
    } on PlatformException {
      return null;
    }
  }

  static Future<void> setLibraryUrl(String url) =>
      _channel.invokeMethod<void>('setLibraryUrl', {'url': url});

  // ------------------------------------------------------------ 界面设置
  //
  // 底部玻璃 TAB 的显隐（`app.show_tab_bar`）：默认隐藏，顶栏按钮提供
  // 「我的壁纸 / 壁纸库」切换入口；设置页里可随时打开。

  static Future<bool> getShowTabBar() async {
    try {
      return await _channel.invokeMethod<bool>('getShowTabBar') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> setShowTabBar(bool visible) =>
      _channel.invokeMethod<void>('setShowTabBar', {'visible': visible});

  // ------------------------------------------------------------ 显示语言
  //
  // 存在原生 `zuno_config`（`app.language`）：值为 "system" 或受支持的
  // 语言代码（en / zh / zh_Hant / ja / ko / es / fr / de）。首帧前读取，
  // 避免先按英文渲染再跳变。

  static Future<String?> getAppLanguage() async {
    try {
      return await _channel.invokeMethod<String>('getAppLanguage');
    } on PlatformException {
      return null;
    }
  }

  static Future<void> setAppLanguage(String code) =>
      _channel.invokeMethod<void>('setAppLanguage', {'code': code});

  // ------------------------------------------------------------ 账号会话
  //
  // 存在原生 `zuno_auth` prefs（应用私有目录）。为什么不放 D1/远端：
  // 这是本机会话凭据，离线也要能读出来渲染“我的”页；为什么不新建
  // secure storage 依赖：token 只在本进程内用于设置 HTTP 头，不进日志、
  // 不进 WebView，应用私有目录已经等于其他 App 不可读。

  static Future<Map<String, dynamic>?> loadAuth() async {
    try {
      final v = await _channel.invokeMethod<Map<Object?, Object?>>('authLoad');
      return v?.cast<String, Object?>();
    } on PlatformException {
      return null;
    }
  }

  static Future<void> saveAuth({
    required String token,
    required String userId,
    required String email,
    required int expiresAt,
  }) => _channel.invokeMethod<void>('authSave', {
    'token': token,
    'userId': userId,
    'email': email,
    'expiresAt': expiresAt,
  });

  static Future<void> clearAuth() => _channel.invokeMethod<void>('authClear');

  /// 导入后为 video/depth 包自动生成缩略图（原生取视频首帧 / 缩放颜色图）。
  /// 返回生成的 JPEG 路径；失败或类型不支持返回 null（UI 显示占位图标）。
  static Future<String?> ensureThumbnail({
    required String dir,
    required String type,
    required String entryPath,
    required String outPath,
  }) async {
    try {
      return await _channel.invokeMethod<String>('ensureThumbnail', {
        'dir': dir,
        'type': type,
        'entry': entryPath,
        'outPath': outPath,
      });
    } on PlatformException {
      return null;
    }
  }
}
