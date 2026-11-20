import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/core/zuno_paths.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/endpoint_controller.dart';
import 'package:zuno/state/theme_controller.dart';
import 'package:zuno/ui/screens/about_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// 设置页：壁纸库地址、外观模式、全局性能档位、电池优化白名单、关于。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeController,
    required this.endpoint,
    required this.catalog,
  });

  final ThemeController themeController;
  final EndpointController endpoint;

  /// 保存新地址后要重建目录，否则列表还是旧后端的条目。
  final CatalogController catalog;

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
    ]);
    if (!mounted) return;
    setState(() {
      _tier = results[0] as String? ?? 'medium';
      _batteryIgnored = results[1] as bool? ?? false;
      _decodeMode = results[2] as String? ?? 'auto';
      _decodePrompt = results[3] as bool? ?? true;
      _depthScale = (results[4] as num?)?.toDouble() ?? 1.0;
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
      message: '壁纸库地址已保存',
      type: lgw.GlassToastType.success,
    );
  }

  Future<void> _resetUrl() async {
    await widget.endpoint.resetToDefault();
    if (!mounted) return;
    _urlController.text = widget.endpoint.url;
    setState(() {});
    await widget.catalog.reloadForNewEndpoint();
    if (!mounted) return;
    lgw.GlassToast.show(
      context,
      message: '已恢复默认地址',
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
    final mediaQuery = MediaQuery.of(context);
    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      // 内容滚到玻璃导航栏下方，由 iOS 26/27 的 soft 边缘淡出收尾；
      // extendBody:false 时包不启用边缘淡出，文字会在栏边界被硬切断。
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: const Text('设置'),
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: '返回',
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
                label: '恢复默认',
                onPressed: _resetUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassPrimaryButton(
                icon: AppIcons.check,
                label: '保存',
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
                  _sectionLabel(context, '外观'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: const [
                        lgw.GlassSegment(label: '跟随系统', id: 'system'),
                        lgw.GlassSegment(label: '浅色', id: 'light'),
                        lgw.GlassSegment(label: '深色', id: 'dark'),
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
                      '默认跟随系统外观；切换立即生效，并记住你的选择。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, '性能档位'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: const [
                        lgw.GlassSegment(label: '高', id: 'high'),
                        lgw.GlassSegment(label: '中', id: 'medium'),
                        lgw.GlassSegment(label: '低', id: 'low'),
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
                      '作用于壁纸运行时的各渲染路径（默认“中”）：\n'
                      '· 视频壁纸：高/中 正常播放，低 → 静态首帧\n'
                      '· 深度视差：30 / 20 / 15 fps（省电模式强制 15）\n'
                      '· HTML：高 不限制，中 ~30fps，低 冻结 CSS 动画',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, '视频解码'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: const [
                        lgw.GlassSegment(label: '自动', id: 'auto'),
                        lgw.GlassSegment(label: '硬解', id: 'hardware'),
                        lgw.GlassSegment(label: '软解', id: 'software'),
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
                      '自动：优先硬解，设备没有硬解时才用软解；运行中失败会提示。\n'
                      '硬解：最省电，兼容性取决于设备解码器。\n'
                      '软解：兼容性最广，但耗电、发热明显，高分辨率视频可能掉帧。\n'
                      '音量仍由每个壁纸包的参数控制，默认静音。',
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
                                const Text('解码失败时提示'),
                                const SizedBox(height: 2),
                                Text(
                                  '回到 App 时提示切换软件解码',
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
                  _sectionLabel(context, '深度视差'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: lgw.GlassSegmentedControl(
                      segments: const [
                        lgw.GlassSegment(label: '弱', id: 'soft'),
                        lgw.GlassSegment(label: '标准', id: 'standard'),
                        lgw.GlassSegment(label: '强', id: 'strong'),
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
                      '全局倍率，叠加在每个深度包自己的视差强度上；'
                      '觉得桌面晃动太明显时选“弱”。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel(context, '壁纸库地址'),
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
                        decoration: const InputDecoration(
                          hintText: 'https://api.example.com',
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
                      '当前生效：${widget.endpoint.url}\n'
                      '默认地址：${widget.endpoint.defaultUrl}\n'
                      '自建 zuno-api 时填你自己的 Worker 域名；保存后会立即重建目录。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  lgw.GlassGroupedSection(
                    header: const Text('电池优化'),
                    footer: const Text(
                      '定时壁纸需要后台运行才能准时切换；加入电池优化白名单，'
                      '可避免系统休眠时把切换推迟到很久以后。',
                    ),
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
                          _batteryIgnored ? '已加入电池优化白名单' : '未加入电池优化白名单',
                        ),
                        trailing: _batteryIgnored
                            ? null
                            : Text(
                                '去设置',
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
                        header: const Text('存储'),
                        surfaceStyle: lgw.GlassSurfaceStyle.solid,
                        shape: glassShape(radius: 28),
                        children: [
                          lgw.GlassListTile(
                            leading: appIcon(AppIcons.database),
                            leadingIconColor: scheme.primary,
                            title: const Text('壁纸库占用'),
                            subtitle: const Text('已安装壁纸包文件（应用私有目录）'),
                            trailing: Text(
                              snap.hasData
                                  ? '${mb.toStringAsFixed(1)} MB'
                                  : '统计中…',
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
                        title: const Text('关于 ZUNO'),
                        subtitle: const Text('版本信息 · 交流群'),
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
