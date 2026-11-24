import 'package:flutter/widgets.dart';

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/services/platform_bridge.dart';

/// 显示语言状态（跟随系统 / 指定语言）。
///
/// 与外观模式一样，选择落在原生 `zuno_config`（`app.language`），并在
/// 首帧前读取：否则 MaterialApp 会先按系统语言渲染一帧再跳变。
class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController(this._preference) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 「跟随系统」的持久化值。
  static const String systemPreference = 'system';

  /// 设置页可选的全部值（顺序即展示顺序）。
  static const List<String> preferences = [
    systemPreference,
    ...ZunoStrings.supportedLanguageCodes,
  ];

  String _preference;

  String get preference => _preference;

  /// null = 跟随系统（交给 Flutter 的 locale 解析）。
  Locale? get locale => _preference == systemPreference
      ? null
      : ZunoLocalizations.localeForCode(_preference);

  /// 当前生效的字符串表；「跟随系统」时按平台语言解析。
  ZunoStrings get strings => ZunoStrings.forLanguage(
    _preference == systemPreference
        ? ZunoLocalizations.codeForLocale(
            WidgetsBinding.instance.platformDispatcher.locale,
          )
        : _preference,
  );

  String get languageCode => strings.languageCode;

  /// 设置页副标题：跟随系统时显示当前解析出的语言名。
  String get displayName {
    final code = languageCode;
    return ZunoStrings.nativeNames[code] ?? code;
  }

  static Future<LocaleController> load() async {
    var preference = systemPreference;
    try {
      final stored = await ZunoNative.getAppLanguage();
      if (stored != null && preferences.contains(stored)) {
        preference = stored;
      }
    } catch (_) {
      // 通道失败按跟随系统处理，不阻断启动。
    }
    final controller = LocaleController(preference);
    ZunoStrings.current = controller.strings;
    return controller;
  }

  Future<void> setPreference(String preference) async {
    if (!preferences.contains(preference) || preference == _preference) {
      return;
    }
    // 先写原生（重启后的事实来源），成功后再改内存并广播。
    await ZunoNative.setAppLanguage(preference);
    _preference = preference;
    ZunoStrings.current = strings;
    notifyListeners();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // 只在「跟随系统」时响应；指定语言不受系统切换影响。
    if (_preference == systemPreference) {
      ZunoStrings.current = strings;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
