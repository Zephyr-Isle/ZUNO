import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/endpoint_controller.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/state/locale_controller.dart';
import 'package:zuno/state/shell_prefs_controller.dart';
import 'package:zuno/state/theme_controller.dart';
import 'package:zuno/ui/screens/home_screen.dart';
import 'package:zuno/ui/screens/settings_screen.dart';
import 'package:zuno/ui/screens/wallpaper_library_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/shell_metrics.dart';

/// 主壳：两页签 + 统一的液态玻璃导航栏/底部 TAB。
///
/// 页面本身不再各自持有 `GlassScaffold`，只提供 body；顶部标题和底部
/// `GlassTabBar.bottom` 由这里统一提供，切换页签时底部栏位置保持稳定。
/// 底部 TAB 默认隐藏（[ShellPrefsController]）：顶栏按钮接管页签切换，
/// 「设置 → 界面」里可重新打开。
///
/// 账号页已从主导航移除：下载改为匿名可用后，账号不再是使用壁纸库的
/// 前提。相关页面（AuthScreen / ProfileScreen）保留但不挂载，需要时
/// 再把它加回 `IndexedStack` 即可。
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.controller,
    required this.themeController,
    required this.localeController,
    required this.catalog,
    required this.endpoint,
    required this.shellPrefs,
  });

  final LibraryController controller;
  final ThemeController themeController;
  final LocaleController localeController;
  final CatalogController catalog;
  final EndpointController endpoint;
  final ShellPrefsController shellPrefs;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  bool _decodeDialogOpen = false;
  bool _decodePromptDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 壁纸解码失败发生在 App 可能不在前台的时候，首帧后检查一次；
    // 之后每次回到前台再检查（用户可能在设置里换了壁纸/解码方式）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDecodeFailure());
    // 启动引导：系统壁纸还不是 ZUNO 时，首帧渲染后弹一次“设为动态壁纸”。
    // 引导放在壳层而不是“我的壁纸”页 —— tab 页是切换时才挂载的
    // （修复玻璃穿透），放进页内会每次切回该页都重复弹窗。
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestWallpaperRole(),
    );
  }

  /// 启动引导：系统壁纸还不是 ZUNO 时，弹窗引导去系统壁纸预览页。
  Future<void> _requestWallpaperRole() async {
    var live = widget.controller.liveWallpaperActive;
    // 激活记录已存在但系统侧报告"未激活"：多半处于壁纸服务重绑窗口期
    // （进程重启后 WallpaperManager.wallpaperInfo 短暂返回 null，即使系统
    // 记录的组件就是 ZUNO）。延迟复查一次再决定，避免每次重启都误弹引导。
    if (!live && widget.controller.activeWallpaper != null) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      await widget.controller.refresh();
      live = widget.controller.liveWallpaperActive;
    }
    if (live || widget.controller.importing) {
      return;
    }
    if (!mounted) return;
    final s = ZunoLocalizations.of(context);
    final confirmed = await lgw.GlassDialog.show<bool>(
      context: context,
      title: s.setWallpaperTitle,
      message: s.setWallpaperMessage,
      actions: [
        lgw.GlassDialogAction(
          label: s.later,
          onPressed: () => Navigator.pop(context, false),
        ),
        lgw.GlassDialogAction(
          label: s.goSet,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed == true && mounted) {
      await ZunoNative.launchWallpaperPreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refresh();
      _checkDecodeFailure();
    }
  }

  /// 打开设置页。壁纸库地址、外观、界面、解码方式都在这里，两处入口共用。
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          themeController: widget.themeController,
          localeController: widget.localeController,
          endpoint: widget.endpoint,
          catalog: widget.catalog,
          shellPrefs: widget.shellPrefs,
        ),
      ),
    );
  }

  Future<void> _checkDecodeFailure() async {
    if (!mounted || _decodeDialogOpen || _decodePromptDismissed) return;
    final failure = await ZunoNative.getVideoDecodeFailure();
    if (failure == null || !mounted) return;
    // 失败记录属于旧壁纸：清掉，不在当前壁纸上误导用户。
    final entryId = failure['entryId'] as String?;
    final activeId = widget.controller.activeId;
    if (activeId != null && entryId != null && entryId != activeId) {
      await ZunoNative.clearVideoDecodeFailure();
      return;
    }
    final mode = failure['mode'] as String? ?? 'auto';
    final alreadySoftware = mode == 'software';
    final s = ZunoLocalizations.of(context);
    _decodeDialogOpen = true;
    final choice = await lgw.GlassDialog.show<String>(
      context: context,
      title: alreadySoftware
          ? s.decodeSoftwareFailedTitle
          : s.decodeHardwareFailedTitle,
      message: alreadySoftware
          ? s.decodeSoftwareFailedMessage
          : s.decodeHardwareFailedMessage,
      actions: alreadySoftware
          ? [
              lgw.GlassDialogAction(
                label: s.gotIt,
                isPrimary: true,
                onPressed: () => Navigator.pop(context, 'ok'),
              ),
            ]
          : [
              lgw.GlassDialogAction(
                label: s.later,
                onPressed: () => Navigator.pop(context, 'later'),
              ),
              lgw.GlassDialogAction(
                label: s.neverAsk,
                onPressed: () => Navigator.pop(context, 'never'),
              ),
              lgw.GlassDialogAction(
                label: s.useSoftware,
                isPrimary: true,
                onPressed: () => Navigator.pop(context, 'software'),
              ),
            ],
    );
    _decodeDialogOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'software':
        await ZunoNative.setVideoDecodeMode('software');
        await ZunoNative.clearVideoDecodeFailure();
        if (!mounted) return;
        lgw.GlassToast.show(
          context,
          message: s.switchedToSoftware,
          type: lgw.GlassToastType.success,
        );
      case 'never':
        await ZunoNative.setVideoDecodePrompt(false);
        await ZunoNative.clearVideoDecodeFailure();
      case 'ok':
        await ZunoNative.clearVideoDecodeFailure();
      case 'later':
        _decodePromptDismissed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = ZunoLocalizations.of(context);
    // shellPrefs（TAB 显隐）与 endpoint（壁纸库地址）都可能在设置页里被改，
    // 回到壳层时这两处状态要立即反映：合并监听，任一 notify 都整壳重建。
    return ListenableBuilder(
      listenable: Listenable.merge([widget.shellPrefs, widget.endpoint]),
      builder: (context, _) {
        final tabBarVisible = widget.shellPrefs.showTabBar;
        return lgw.GlassScaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarStyle: zunoStatusBarStyle(context),
          // 内容滚动到玻璃栏下方并用 iOS 26/27 的 soft 边缘淡出收尾
          // （extendBody:false 时包不会启用边缘淡出，内容会在栏边界被硬切，
          // 文字被拦腰截断）。页面自己的滚动视图负责补出 app bar / TAB 的高度。
          extendBody: true,
          appBar: lgw.GlassAppBar(
            title: Text(
              _selectedIndex == 0 ? s.myWallpapers : s.wallpaperLibrary,
            ),
            centerTitle: true,
            actions: [
              // 底部 TAB 隐藏时，顶栏按钮接管页签切换：本页图标指向另一页。
              if (!tabBarVisible) ...[
                GlassCircleButton(
                  icon: _selectedIndex == 0 ? AppIcons.grid : AppIcons.photo,
                  semanticLabel: _selectedIndex == 0
                      ? s.openLibrary
                      : s.backToMyWallpapers,
                  onPressed: () => setState(
                    () => _selectedIndex = _selectedIndex == 0 ? 1 : 0,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 刷新只对“壁纸库”有意义：目录是远端数据，另一页是本地状态。
              if (_selectedIndex == 1) ...[
                GlassCircleButton(
                  icon: AppIcons.refresh,
                  semanticLabel: s.refreshLibrary,
                  onPressed: widget.catalog.refresh,
                ),
                const SizedBox(width: 8),
              ],
              GlassCircleButton(
                icon: AppIcons.settings,
                semanticLabel: s.settingsSemantic,
                onPressed: () => _openSettings(context),
              ),
            ],
          ),
          body: Material(
            // GlassScaffold 是 Cupertino 骨架，给 Material 控件补 ancestor。
            type: MaterialType.transparency,
            // 只挂载当前页签。绝不能用 IndexedStack 保活两页：未选中页加入
            // 页面级玻璃层（GlassPage 的 AdaptiveLiquidGlassLayer）的 premium
            // 玻璃面（GlassContainer.card / GlassButton）会被该层整体绘制，
            // 不受 IndexedStack 只画选中子项的约束 —— 另一页的玻璃卡片/按钮
            // 会“穿透”叠在当前页上（幽灵组件），滚动时看着像部分组件变形。
            // useOwnLayer: true 的控件不受影响，但逐个加 ownLayer 既贵又易漏。
            child: _selectedIndex == 0
                ? HomeScreen(
                    controller: widget.controller,
                    tabBarVisible: tabBarVisible,
                  )
                // 未配置后端地址时不挂载壁纸库页：避免对空 URL 发请求，
                // 先引导去设置页填写（地址保存在原生 zuno_config）。
                : !widget.endpoint.isConfigured
                ? _LibraryNotConfigured(
                    onOpenSettings: () => _openSettings(context),
                    tabBarVisible: tabBarVisible,
                  )
                : WallpaperLibraryScreen(
                    catalog: widget.catalog,
                    library: widget.controller,
                    onOpenSettings: () => _openSettings(context),
                    tabBarVisible: tabBarVisible,
                  ),
          ),
          bottomBar: !tabBarVisible
              ? null
              : lgw.GlassTabBar.bottom(
                  tabs: [
                    // 选中前后共用同一字形：HugeIcons 只有 stroke 描边风格，
                    // 若用两个字形模拟选中态，切换页签时图标会“变形”。
                    // 选中态只靠颜色（primary vs onSurfaceVariant）+ 标签字重区分。
                    lgw.GlassTab(
                      icon: appIcon(AppIcons.photo),
                      label: s.myWallpapers,
                    ),
                    lgw.GlassTab(
                      icon: appIcon(AppIcons.grid),
                      label: s.wallpaperLibrary,
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  selectedIconColor: scheme.primary,
                  unselectedIconColor: scheme.onSurfaceVariant,
                  selectedLabelColor: scheme.primary,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  // 屏蔽模拟器系统拼写检查给 TAB 文字画的黄色下划线。
                  // 注意：这些 style 会整体替换包内默认样式，必须显式带回 11px。
                  textStyle: const TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                  selectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                  quality: lgw.GlassQuality.premium,
                  // Apple 的悬浮 TAB 是真正的胶囊：用包的 capsule 哨兵值，玻璃着色器
                  // 会把圆角钳到高度的一半，拖动/按压膨胀时也始终是椭圆端，不会变成
                  // 一个圆角矩形。选中指示块用同一个值（水滴两端也是半椭圆），
                  // 否则拖动时胶囊条里会出现一块方角高光。
                  barBorderRadius: lgw.GlassDefaults.capsuleRadius,
                  barHeight: 66,
                  spacing: 10,
                  horizontalPadding: 22,
                  verticalPadding: 18,
                  indicatorBorderRadius: lgw.GlassDefaults.capsuleRadius,
                  indicatorExpansion: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  indicatorPinchStrength: 0.5,
                  // 选中项图标轻微抬起，和 iOS 的 tab magnification 一致。
                  magnification: 1.05,
                ),
        );
      },
    );
  }
}

/// 壁纸库未配置空态：ZUNO 不内置云端服务，地址指向用户自己部署的
/// zuno-api。这里只引导去设置页填写，不发起任何网络请求。
class _LibraryNotConfigured extends StatelessWidget {
  const _LibraryNotConfigured({
    required this.onOpenSettings,
    required this.tabBarVisible,
  });

  final VoidCallback onOpenSettings;

  /// 外壳当前是否显示底部玻璃 TAB：净空必须跟随实际值，否则开着
  /// 底部栏时空态的按钮会被玻璃栏压住。
  final bool tabBarVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ZunoLocalizations.of(context);
    final clearBottom =
        shellBottomClearance(context, tabBarVisible: tabBarVisible) + 24;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, clearBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(AppIcons.cloud, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(s.libraryNotConfiguredTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              s.libraryNotConfiguredBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 220,
              child: GlassPrimaryButton(
                icon: AppIcons.settings,
                label: s.goSettings,
                onPressed: onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
