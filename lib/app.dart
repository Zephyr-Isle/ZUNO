import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/endpoint_controller.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/state/theme_controller.dart';
import 'package:zuno/ui/screens/main_shell_screen.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

class ZunoApp extends StatelessWidget {
  const ZunoApp({
    super.key,
    required this.controller,
    required this.themeController,
    required this.endpoint,
    required this.catalog,
  });

  final LibraryController controller;
  final ThemeController themeController;
  final EndpointController endpoint;
  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    // ThemeController 是外观的唯一来源：设置页改动后 MaterialApp 立即重建，
    // 玻璃主题经 brightnessResolver: Theme.maybeBrightnessOf 同步切换明暗变体。
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'ZUNO',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: MainShellScreen(
          controller: controller,
          themeController: themeController,
          endpoint: endpoint,
          catalog: catalog,
        ),
      ),
    );
  }
}

/// 外观主题：浅色是白玻璃 + 浅灰紫底，深色是深灰紫底 + 深色玻璃。
///
/// 强调色固定为 [zunoAccent]：`ColorScheme.fromSeed` 生成的 tonal primary
/// 与导入按钮的蓝不一致，会让 TAB、滑杆、徽标各显示一种蓝。
ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? zunoPageBackgroundDark : zunoPageBackground;
  final fieldBorder = dark ? const Color(0xFF3A3941) : const Color(0xFFD5D4DD);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: zunoAccent,
        brightness: brightness,
      ).copyWith(
        primary: zunoAccent,
        onPrimary: Colors.white,
        surface: background,
        surfaceContainerLowest: dark
            ? const Color(0xFF1C1C1E)
            : Colors.white,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    // Apple 控件靠玻璃自身的按压/高光反馈，不用 Material 水波纹。
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: dark ? const Color(0xFF2C2B31) : const Color(0xFFD9D8E0),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: dark
          ? const Color(0xFFF5F4F8)
          : const Color(0xFF1C1C1E),
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1C1B21) : const Color(0x99FFFFFF),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: zunoAccent, width: 1.5),
      ),
    ),
    // GlassAppBar 的标题样式取自 CupertinoTheme 的 navTitleTextStyle：
    // 17pt / 600 / 负字距，才是 iOS 的导航栏字形，而不是 Material 的 20pt。
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: zunoAccent,
      textTheme: CupertinoTextThemeData(
        navTitleTextStyle: TextStyle(
          color: dark ? const Color(0xFFF5F4F8) : const Color(0xFF1C1C1E),
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          decoration: TextDecoration.none,
        ),
      ),
    ),
    // 页面切换也走 iOS 的横向滑动，和 GlassScaffold 的 Cupertino 结构一致。
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
  // SF Pro 比 Roboto 字距更紧；负字距 + 600 字重让中文/数字更接近 iOS。
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(letterSpacing: -0.15),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: -0.1),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
  );
}
