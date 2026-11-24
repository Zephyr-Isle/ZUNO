import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/state/locale_controller.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// 语言选择页：跟随系统 + 8 种受支持语言。
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = ZunoLocalizations.of(context);
        return lgw.GlassScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarStyle: zunoStatusBarStyle(context),
          extendBody: true,
          appBar: lgw.GlassAppBar(
            title: Text(s.languageTitle),
            leading: GlassCircleButton(
              icon: AppIcons.back,
              semanticLabel: s.back,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                mediaQuery.padding.top + 44 + 12,
                16,
                mediaQuery.padding.bottom + 24,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    s.languageDescription,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                lgw.GlassGroupedSection(
                  surfaceStyle: lgw.GlassSurfaceStyle.solid,
                  shape: glassShape(radius: 28),
                  children: [
                    for (final preference in LocaleController.preferences)
                      _LanguageTile(
                        preference: preference,
                        selected: controller.preference == preference,
                        onTap: () => controller.setPreference(preference),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  final String preference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ZunoLocalizations.of(context);
    final isSystem = preference == LocaleController.systemPreference;
    final title = isSystem
        ? s.languageSystem
        : ZunoStrings.nativeNames[preference] ?? preference;
    final subtitle = isSystem
        ? '${s.languageCurrent}: ${_resolvedName()}'
        : null;
    return lgw.GlassListTile(
      leading: appIcon(
        isSystem ? AppIcons.settings : AppIcons.language,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? scheme.primary : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected
          ? appIcon(AppIcons.check, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }

  String _resolvedName() {
    if (preference != LocaleController.systemPreference) {
      return ZunoStrings.nativeNames[preference] ?? preference;
    }
    final code = ZunoStrings.forLanguage(
      ZunoLocalizations.codeForLocale(
        WidgetsBinding.instance.platformDispatcher.locale,
      ),
    ).languageCode;
    return ZunoStrings.nativeNames[code] ?? code;
  }
}
