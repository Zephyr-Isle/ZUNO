import 'package:flutter/material.dart';

import 'package:zuno/services/platform_bridge.dart';

/// 应用外观模式（跟随系统 / 浅色 / 深色）。
///
/// 选择持久化在原生 `zuno_config` prefs（`app.theme_mode`）：
/// 与性能档位一样，Dart 不引入 shared_preferences，写入统一走 `zuno/native`。
class ThemeController extends ChangeNotifier {
  ThemeController(this._mode);

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// 设置页分段控件的顺序（默认“跟随系统”）。
  static const List<ThemeMode> modes = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  /// 启动时读取上次选择；通道异常/未知值一律回落到跟随系统。
  static Future<ThemeController> load() async {
    final stored = await ZunoNative.getThemeMode();
    return ThemeController(_decode(stored));
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    // 先改内存并通知，MaterialApp 立即换主题；落盘在后台完成。
    _mode = mode;
    notifyListeners();
    await ZunoNative.setThemeMode(_encode(mode));
  }

  static ThemeMode _decode(String stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
