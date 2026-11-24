import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'zuno_strings.dart';

// UI 代码统一只 import 本文件即可拿到 ZunoStrings 与 ZunoLocalizations.of(context)。
export 'zuno_strings.dart';

/// Flutter binding for [ZunoStrings].
///
/// The string catalogue itself is pure Dart (the import isolate uses it); this
/// delegate only resolves it from the widget tree and keeps
/// [ZunoStrings.current] in sync for controllers and other context-free code.
class ZunoLocalizations {
  ZunoLocalizations._();

  static const LocalizationsDelegate<ZunoStrings> delegate =
      _ZunoStringsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
    Locale('ko'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
  ];

  static const List<LocalizationsDelegate<dynamic>> delegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Maps a platform locale to one of [ZunoStrings.supportedLanguageCodes],
  /// falling back to English for unsupported languages.
  ///
  /// Chinese needs script/country detection: Taiwan, Hong Kong and Macau use
  /// Traditional Chinese, everything else defaults to Simplified.
  static String codeForLocale(Locale locale) => _matchCode(locale) ?? 'en';

  /// Returns the supported code for [locale], or null when the language is not
  /// translated. [resolveLocale] needs the distinction to keep scanning the
  /// user's preference list instead of stopping at the first unknown language.
  static String? _matchCode(Locale locale) {
    if (locale.languageCode == 'zh') {
      final script = locale.scriptCode;
      final country = locale.countryCode;
      if (script == 'Hant' ||
          country == 'TW' ||
          country == 'HK' ||
          country == 'MO') {
        return 'zh_Hant';
      }
      return 'zh';
    }
    final code = locale.languageCode;
    return ZunoStrings.supportedLanguageCodes.contains(code) ? code : null;
  }

  static Locale localeForCode(String code) => switch (code) {
    'zh' => const Locale('zh'),
    'zh_Hant' => Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    'ja' => const Locale('ja'),
    'ko' => const Locale('ko'),
    'es' => const Locale('es'),
    'fr' => const Locale('fr'),
    'de' => const Locale('de'),
    _ => const Locale('en'),
  };

  /// Picks the first supported locale from the platform preference list.
  static Locale? resolveLocale(
    List<Locale>? preferred,
    Iterable<Locale> supported,
  ) {
    for (final locale in preferred ?? const <Locale>[]) {
      final code = _matchCode(locale);
      if (code != null) return localeForCode(code);
    }
    return const Locale('en');
  }

  static ZunoStrings of(BuildContext context) =>
      Localizations.of<ZunoStrings>(context, ZunoStrings) ??
      ZunoStrings.current;
}

class _ZunoStringsDelegate extends LocalizationsDelegate<ZunoStrings> {
  const _ZunoStringsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<ZunoStrings> load(Locale locale) {
    final strings = ZunoStrings.forLanguage(
      ZunoLocalizations.codeForLocale(locale),
    );
    ZunoStrings.current = strings;
    return SynchronousFuture<ZunoStrings>(strings);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<ZunoStrings> old) => false;
}
