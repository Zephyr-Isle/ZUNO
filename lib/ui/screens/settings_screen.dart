import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/core/zuno_paths.dart';
import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/endpoint_controller.dart';
import 'package:zuno/state/locale_controller.dart';
import 'package:zuno/state/shell_prefs_controller.dart';
import 'package:zuno/state/theme_controller.dart';
import 'package:zuno/ui/screens/about_screen.dart';
import 'package:zuno/ui/screens/language_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// 设置页：壁纸库地址、外观模式、界面、全局性能档位、电池优化白名单、关于。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    required this.endpoint,
    required this.catalog,
    required this.shellPrefs,
  });

  final ThemeController themeController;
  final LocaleController localeController;
  final EndpointController endpoint;

  /// 保存新地址后要重建目录，否则列表还是旧后端的条目。
  final CatalogController catalog;

  /// 界面偏好（底部玻璃 TAB 显隐）：改动立即反映到主壳。
  final ShellPrefsController shellPrefs;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _tiers = ['high', 'medium', 'low'];
  static const _decodeModes = ['auto', 'hardware', 'software'];
  static const _depthScales = [0.6, 1.0, 1.4];

  String _tier = 'medium';
  String _decodeMode = 'auto';
  bool _decodePrompt = true;
  bool _showTabBar = false; // 与主壳默认一致（隐藏），加载后校正
  double _depthScale = 1.0;
  bool _batteryIgnored = true; // 先按 true 渲染避免闪烁，加载后校正
  bool _loading = true;

  int get _tierIndex {
    final index = _tiers.indexOf(_tier);
    return index < 0 ? 1 : index;
  }

  int get _themeIndex {
    final index = ThemeController.modes.indexOf(widget.themeController.mode);
    return index < 0 ? 0 : index;
  }

  int get _decodeIndex {
    final index = _decodeModes.indexOf(_decodeMode);
    return index < 0 ? 0 : index;
  }

  int get _depthIndex {
    var best = 1;
    var bestDelta = double.infinity;
    for (var i = 0; i < _depthScales.length; i++) {
      final delta = (_depthScales[i] - _depthScale).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  // 存储统计缓存为 Future：setState（切换档位/电池状态）触发重建时不再重扫目录。
  late final Future<int> _sizeFuture;

  /// 壁纸库地址输入框。初值取当前生效值，保存后回填规范化结果。
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _sizeFuture = _librarySizeBytes();
    _urlController = TextEditingController(text: widget.endpoint.url);
    // 外观可能被别处改（如返回后再次进入设置），监听保持分段控件同步。
    widget.themeController.addListener(_onThemeChanged);
    _load();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.themeController.removeListener(_onThemeChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      ZunoNative.getPerformanceTier(),
      ZunoNative.isIgnoringBatteryOptimizations(),
      ZunoNative.getVideoDecodeMode(),
      ZunoNative.getVideoDecodePrompt(),
      ZunoNative.getDepthStrengthScale(),
      ZunoNative.getShowTabBar(),
    ]);
    if (!mounted) return;
    setState(() {
      _tier = results[0] as String? ?? 'medium';
      _batteryIgnored = results[1] as bool? ?? false;
      _decodeMode = results[2] as String? ?? 'auto';
      _decodePrompt = results[3] as bool? ?? true;
      _depthScale = (results[4] as num?)?.toDouble() ?? 1.0;
      _showTabBar = results[5] as bool? ?? false;
      _loading = false;
    });
  }

  Future<void> _setTier(String tier) async {
    await ZunoNative.setPerformanceTier(tier);
    setState(() => _tier = tier);
  }

  Future<void> _setDecodeMode(String mode) async {
    await ZunoNative.setVideoDecodeMode(mode);
    if (mounted) setState(() => _decodeMode = mode);
  }

  Future<void> _setDecodePrompt(bool enabled) async {
    await ZunoNative.setVideoDecodePrompt(enabled);
    if (mounted) setState(() => _decodePrompt = enabled);
  }

  /// 底部玻璃 TAB 显隐：写原生 → 更新控制器（主壳监听后立即重建）→
  /// 本页开关同步。
  Future<void> _setShowTabBar(bool enabled) async {
    await widget.shellPrefs.setShowTabBar(enabled);
    if (mounted) setState(() => _showTabBar = enabled);
  }

  Future<void> _setDepthScale(int index) async {
    final scale = _depthScales[index];
    await ZunoNative.setDepthStrengthScale(scale);
    if (mounted) setState(() => _depthScale = scale);
  }

  /// 保存壁纸库地址：写原生 → 换 RemoteApi 的 baseUrl → 清空并重建目录。
  Future<void> _saveUrl() async {
    final error = await widget.endpoint.setUrl(_urlController.text);
    if (!mounted) return;
    if (error != null) {
      lgw.GlassToast.show(
        context,
        message: error,
        type: lgw.GlassToastType.error,
      );
      return;
    }
    _urlController.text = widget.endpoint.url;
    setState(() {});
    await widget.catalog.reloadForNewEndpoint();
    if (!mounted) return;
    lgw.GlassToast.show(
      context,
      message: ZunoLocalizations.of(context).libraryAddressSaved,
      type: lgw.GlassToastType.success,
    );
  }

  Future<void> _resetUrl() async {
    await widget.endpoint.clearUrl();
    if (!mounted) return;
    _urlController.text = widget.endpoint.url;
    setState(() {});
    await widget.catalog.reloadForNewEndpoint();
    if (!mounted) return;
    lgw.GlassToast.show(
      context,
      message: ZunoLocalizations.of(context).libraryAddressCleared,
      type: lgw.GlassToastType.success,
    );
  }

  Future<void> _requestBattery() async {
    await ZunoNative.requestIgnoreBatteryOptimizations();
    // 用户从系统对话框回来后刷新状态。
    final ignored = await ZunoNative.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() => _batteryIgnored = ignored);
  }

  void _openLanguage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LanguageScreen(controller: widget.localeController),
      ),
    );
  }

  /// 统计壁纸库（已安装包文件）的总大小。
  /// 目录遍历放 Future 里一次性完成；包数量级为个位数/数十位，无性能顾虑。
  Future<int> _librarySizeBytes() async {
    try {
      final root = await ZunoPaths.libraryRoot();
      var total = 0;
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ZunoLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      // 内容滚到玻璃导航栏下方，由 iOS 26/27 的 soft 边缘淡出收尾；
      // extendBody:false 时包不启用边缘淡出，文字会在栏边界被硬切断。
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: Text(s.settingsTitle),
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: s.back,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      // 保存/恢复默认固定在底部：玻璃主按钮放进滚动列表后，premium 玻璃
      // 捕获的背景在滚动中会失效丢色（滑动的瞬间蓝色消失）；固定在
      // bottomBar 位置不变，背景捕获稳定，也符合主 CTA 不进滚动列表的约定。
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: GlassSecondaryButton(
                icon: AppIcons.refresh,
                label: s.clearAddress,
                onPressed: _resetUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassPrimaryButton(
                icon: AppIcons.check,
                label: s.save,
                onPressed: _saveUrl,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(
              child: Padding(
                // extendBody 后首屏内容让出状态栏 + app bar。
                padding: EdgeInsets.only(top: mediaQuery.padding.top + 44),
                child: const CircularProgressIndicator(),
              ),
            )
          : Material(
              // GlassScaffold 内部是 CupertinoPageScaffold，给 Material 文本
              // 控件补 ancestor；透明 Material 不添加背景层。
              type: MaterialType.transparency,
              child: ListView(
                padding: EdgeInsets.only(
                  top: mediaQuery.padding.top + 44 + 12,
                  // 底部让出固定 bottomBar（恢复默认/保存行：10+52+8=70）
                  // 与安全区，最后一组“关于”才能完整滚出按钮区。
                  bottom: mediaQuery.padding.bottom + 70 + 16,
                ),
                children: [
                  _sectionLabel(context, s.appearance),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: [
                        lgw.GlassSegment(label: s.followSystem, id: 'system'),
                        lgw.GlassSegment(label: s.light, id: 'light'),
                        lgw.GlassSegment(label: s.dark, id: 'dark'),
                      ],
                      selectedIndex: _themeIndex,
                      onSegmentSelected: (index) => widget.themeController
                          .setMode(ThemeController.modes[index]),
                      height: 44,
                      quality: lgw.GlassQuality.premium,
                      selectedTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Text(
                      s.appearanceHint,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.interfaceSection),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassContainer.card(
                      shape: glassShape(radius: 24),
                      surfaceStyle: lgw.GlassSurfaceStyle.solid,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.showTabBar),
                                const SizedBox(height: 2),
                                Text(
                                  s.showTabBarHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          lgw.GlassSwitch(
                            value: _showTabBar,
                            onChanged: _setShowTabBar,
                            width: 51,
                            height: 31,
                            activeColor: scheme.primary,
                            quality: lgw.GlassQuality.premium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.languageTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassGroupedSection(
                      surfaceStyle: lgw.GlassSurfaceStyle.solid,
                      shape: glassShape(radius: 28),
                      children: [
                        lgw.GlassListTile(
                          leading: appIcon(AppIcons.language),
                          leadingIconColor: scheme.primary,
                          title: Text(s.languageTitle),
                          subtitle: Text(
                            widget.localeController.preference ==
                                    LocaleController.systemPreference
                                ? '${s.languageSystem} · ${widget.localeController.displayName}'
                                : widget.localeController.displayName,
                          ),
                          trailing: appIcon(
                            AppIcons.chevronRight,
                            color: scheme.onSurfaceVariant,
                          ),
                          onTap: _openLanguage,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.performanceTier),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: [
                        lgw.GlassSegment(label: s.tierHigh, id: 'high'),
                        lgw.GlassSegment(label: s.tierMedium, id: 'medium'),
                        lgw.GlassSegment(label: s.tierLow, id: 'low'),
                      ],
                      selectedIndex: _tierIndex,
                      onSegmentSelected: (index) => _setTier(_tiers[index]),
                      height: 44,
                      quality: lgw.GlassQuality.premium,
                      selectedTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Text(
                      s.performanceHintBody,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.videoDecode),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: [
                        lgw.GlassSegment(label: s.decodeAuto, id: 'auto'),
                        lgw.GlassSegment(
                          label: s.decodeHardware,
                          id: 'hardware',
                        ),
                        lgw.GlassSegment(
                          label: s.decodeSoftware,
                          id: 'software',
                        ),
                      ],
                      selectedIndex: _decodeIndex,
                      onSegmentSelected: (index) =>
                          _setDecodeMode(_decodeModes[index]),
                      height: 44,
                      quality: lgw.GlassQuality.premium,
                      selectedTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Text(
                      s.decodeHintBody,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassContainer.card(
                      shape: glassShape(radius: 24),
                      surfaceStyle: lgw.GlassSurfaceStyle.solid,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.decodePrompt),
                                const SizedBox(height: 2),
                                Text(
                                  s.decodePromptHint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          lgw.GlassSwitch(
                            value: _decodePrompt,
                            onChanged: _setDecodePrompt,
                            width: 51,
                            height: 31,
                            activeColor: scheme.primary,
                            quality: lgw.GlassQuality.premium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.depthParallax),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: [
                        lgw.GlassSegment(label: s.depthSoft, id: 'soft'),
                        lgw.GlassSegment(
                          label: s.depthStandard,
                          id: 'standard',
                        ),
                        lgw.GlassSegment(label: s.depthStrong, id: 'strong'),
                      ],
                      selectedIndex: _depthIndex,
                      onSegmentSelected: _setDepthScale,
                      height: 44,
                      quality: lgw.GlassQuality.premium,
                      selectedTextStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Text(
                      s.depthHint,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, s.libraryAddress),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GlassSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveUrl(),
                        decoration: InputDecoration(
                          hintText: s.addressHint,
                          // 主题给输入框默认加了填充与描边；放在玻璃卡里
                          // 会把卡面画成实心色块，这里只保留光标和文字。
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  // 恢复默认 / 保存按钮固定在 GlassScaffold.bottomBar
                  // （玻璃按钮随列表滚动时会因背景捕获失效而丢色）。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                    child: Text(
                      widget.endpoint.isConfigured
                          ? s.addressConfigured(widget.endpoint.url)
                          : s.addressNotConfigured,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  lgw.GlassGroupedSection(
                    header: Text(s.batteryOptimization),
                    footer: Text(s.batteryFooter),
                    // iOS 原生分组卡是平实不透明面：纯文字/行卡片走 solid，
                    // 不吃玻璃雾（premium frost 会把卡面文字糊成雾中残影）。
                    surfaceStyle: lgw.GlassSurfaceStyle.solid,
                    shape: glassShape(radius: 28),
                    children: [
                      lgw.GlassListTile(
                        leading: appIcon(
                          _batteryIgnored
                              ? AppIcons.batteryFull
                              : AppIcons.batteryWarning,
                        ),
                        leadingIconColor: _batteryIgnored
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF9500),
                        title: Text(
                          _batteryIgnored
                              ? s.batteryAllowed
                              : s.batteryNotAllowed,
                        ),
                        trailing: _batteryIgnored
                            ? null
                            : Text(
                                s.goSettings,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        onTap: _batteryIgnored ? null : _requestBattery,
                      ),
                    ],
                  ),
                  FutureBuilder<int>(
                    future: _sizeFuture,
                    builder: (context, snap) {
                      final mb = (snap.data ?? 0) / (1024 * 1024);
                      return lgw.GlassGroupedSection(
                        header: Text(s.storage),
                        surfaceStyle: lgw.GlassSurfaceStyle.solid,
                        shape: glassShape(radius: 28),
                        children: [
                          lgw.GlassListTile(
                            leading: appIcon(AppIcons.database),
                            leadingIconColor: scheme.primary,
                            title: Text(s.libraryUsage),
                            subtitle: Text(s.libraryUsageSubtitle),
                            trailing: Text(
                              snap.hasData
                                  ? '${mb.toStringAsFixed(1)} MB'
                                  : s.calculating,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  lgw.GlassGroupedSection(
                    surfaceStyle: lgw.GlassSurfaceStyle.solid,
                    shape: glassShape(radius: 28),
                    children: [
                      lgw.GlassListTile(
                        leading: appIcon(AppIcons.info),
                        leadingIconColor: scheme.primary,
                        title: Text(s.aboutZuno),
                        subtitle: Text(s.aboutZunoSubtitle),
                        trailing: appIcon(
                          AppIcons.chevronRight,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
