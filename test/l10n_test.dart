import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuno/l10n/strings_de.dart';
import 'package:zuno/l10n/strings_en.dart';
import 'package:zuno/l10n/strings_es.dart';
import 'package:zuno/l10n/strings_fr.dart';
import 'package:zuno/l10n/strings_ja.dart';
import 'package:zuno/l10n/strings_ko.dart';
import 'package:zuno/l10n/strings_zh.dart';
import 'package:zuno/l10n/strings_zh_hant.dart';
import 'package:zuno/l10n/zuno_localizations.dart';

/// 语言资源一致性：任何新增 key 都必须同时补齐 8 种语言，且占位符不能漏。
void main() {
  const tables = <String, Map<String, String>>{
    'en': zunoStringsEn,
    'zh': zunoStringsZh,
    'zh_Hant': zunoStringsZhHant,
    'ja': zunoStringsJa,
    'ko': zunoStringsKo,
    'es': zunoStringsEs,
    'fr': zunoStringsFr,
    'de': zunoStringsDe,
  };

  test('8 种语言的 key 集合完全一致', () {
    final reference = zunoStringsEn.keys.toSet();
    expect(reference, isNotEmpty);
    for (final entry in tables.entries) {
      expect(entry.value.keys.toSet(), reference, reason: entry.key);
    }
  });

  test('每个 key 的占位符集合一致', () {
    final placeholder = RegExp(r'\{[A-Za-z0-9_]+\}');
    for (final entry in tables.entries) {
      for (final key in zunoStringsEn.keys) {
        Set<String> of(String text) =>
            placeholder.allMatches(text).map((m) => m[0]!).toSet();
        expect(
          of(entry.value[key]!),
          of(zunoStringsEn[key]!),
          reason: '${entry.key}/$key',
        );
      }
    }
  });

  test('语言码归一化与繁体识别', () {
    expect(ZunoStrings.normalizeCode('zh-Hant'), 'zh_Hant');
    expect(ZunoStrings.normalizeCode('zh_Hant_TW'), 'zh_Hant');
    expect(ZunoStrings.normalizeCode('pt-BR'), 'en');
    expect(ZunoStrings.forLanguage('ja').languageCode, 'ja');

    expect(ZunoLocalizations.codeForLocale(const Locale('zh')), 'zh');
    expect(
      ZunoLocalizations.codeForLocale(
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'zh_Hant',
    );
    expect(
      ZunoLocalizations.codeForLocale(const Locale('zh', 'TW')),
      'zh_Hant',
    );
    expect(
      ZunoLocalizations.codeForLocale(const Locale('zh', 'HK')),
      'zh_Hant',
    );
    expect(ZunoLocalizations.codeForLocale(const Locale('fr', 'CA')), 'fr');
    expect(ZunoLocalizations.codeForLocale(const Locale('pt', 'BR')), 'en');
  });

  test('系统偏好列表跳过不支持的语言', () {
    final resolved = ZunoLocalizations.resolveLocale(
      const [Locale('pt', 'BR'), Locale('ja', 'JP')],
      ZunoLocalizations.supportedLocales,
    );
    expect(resolved, const Locale('ja'));
    expect(
      ZunoLocalizations.resolveLocale(null, ZunoLocalizations.supportedLocales),
      const Locale('en'),
    );
  });

  test('字符串表按语言返回对应文案', () {
    expect(ZunoStrings.forLanguage('zh').save, '保存');
    expect(ZunoStrings.forLanguage('zh_Hant').save, '儲存');
    expect(ZunoStrings.forLanguage('ja').save, '保存');
    expect(ZunoStrings.forLanguage('en').save, 'Save');
    expect(ZunoStrings.forLanguage('unknown').save, 'Save');
  });
}
