import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/ui/screens/wallpaper_detail_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/package_card.dart';
import 'package:zuno/ui/widgets/shell_metrics.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';

/// “我的壁纸”页：网格展示已安装的 ZUNO 包，悬浮玻璃按钮触发 ZIP/.zuno 导入。
///
/// 顶部导航栏与底部 TAB 由 [MainShellScreen] 统一提供；本页只输出 body。
/// 导入按钮固定在 body 底部（外壳已把 body 裁在 TAB 上方），滚动时不动。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.tabBarVisible,
  });

  final LibraryController controller;

  /// 外壳当前是否显示底部玻璃 TAB：决定导入按钮和列表的底部净空。
  final bool tabBarVisible;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // controller 状态变化（导入中 / 激活壁纸刷新）必须触发整页重建：
    // FAB 的显隐依赖 importing，而页面里的 AnimatedBuilder 只覆盖网格子树，
    // 没有这个监听时 FAB 的可见性会停留在上一次 build 的快照（导入期间不隐藏）。
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refresh();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _import() async {
    final entry = await widget.controller.importPackage();
    if (!mounted) return;
    if (entry != null) {
      // 非致命提醒（如视频编码不在规格支持列表）：先展示，再进详情页。
      final warnings = widget.controller.lastImportWarnings;
      if (warnings.isNotEmpty) {
        await _showWarnings(warnings);
        if (!mounted) return;
      }
      // 导入成功：直达详情页（应用/调参是导入后的自然下一步）。
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WallpaperDetailScreen(
            controller: widget.controller,
            entry: entry,
          ),
        ),
      );
      return;
    }
    final result = widget.controller.lastImportResult;
    if (result is ImportFailure) {
      _showIssues(result);
    } else if (result != null) {
      // lastImportResult 非空但不是失败报告：文件无法读取等边缘情况。
      lgw.GlassToast.show(
        context,
        message: ZunoLocalizations.of(context).importFailedUnreadable,
        type: lgw.GlassToastType.error,
      );
    }
    // result == null → 用户取消，静默返回。
  }

  Future<void> _showWarnings(List<String> warnings) {
    final s = ZunoLocalizations.of(context);
    return lgw.GlassDialog.show<void>(
      context: context,
      title: s.importSuccessWarnings,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(w)),
        ],
      ),
      actions: [
        lgw.GlassDialogAction(
          label: s.gotIt,
          isPrimary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showIssues(ImportFailure failure) {
    final s = ZunoLocalizations.of(context);
    lgw.GlassModalSheet.show<void>(
      context: context,
      halfSize: 0.55,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Row(
              children: [
                appIcon(
                  AppIcons.error,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  s.importRejected,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...failure.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${issue.message}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final s = ZunoLocalizations.of(context);
    // 外壳（MainShellScreen）已经提供 GlassScaffold、顶部导航栏和底部
    // TAB，且 extendBody: true：body 铺满整屏，滚动内容会钻进玻璃栏下方，
    // 由外壳的 soft 边缘淡出收尾。这里用 MediaQuery 补出两根栏的高度，
    // 让首屏内容落在栏外；悬浮 CTA 钉在玻璃 TAB 上方，滚动时不动。
    final mediaQuery = MediaQuery.of(context);
    // 底部净空由外壳状态决定：TAB 可见时让出玻璃栏 + 安全区，隐藏时只
    // 让出安全区（度量集中在 shell_metrics.dart，壁纸库页共用同一份）。
    final bottomBarTotal = shellBottomClearance(
      context,
      tabBarVisible: widget.tabBarVisible,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (controller.importing) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(s.importingPackage),
                    ],
                  ),
                );
              }
              final entries = controller.entries;
              if (entries.isEmpty) {
                return const _EmptyState();
              }
              return GridView.builder(
                // 顶部让出状态栏 + app bar；底部让出 TAB + 悬浮导入按钮。
                padding: EdgeInsets.fromLTRB(
                  16,
                  mediaQuery.padding.top + 44 + 12,
                  16,
                  bottomBarTotal + 12 + 52 + 12,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return PackageCard(
                    entry: entry,
                    // timed 父包也要正确显示"使用中"（激活的是其 slot 子包）。
                    active: controller.isEntryActive(entry),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WallpaperDetailScreen(
                          controller: controller,
                          entry: entry,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!controller.importing)
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomBarTotal + 12,
            child: GlassPrimaryButton(
              icon: AppIcons.importBox,
              label: s.importZuno,
              onPressed: _import,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ZunoLocalizations.of(context);
    // extendBody 后 body 铺满整屏：底部让出 TAB + 悬浮导入按钮的高度，
    // 空态内容才不会撞在玻璃栏上。
    final clearBottom =
        102.0 + MediaQuery.paddingOf(context).bottom + 12 + 52 + 12;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, clearBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(AppIcons.image, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(s.emptyLibraryTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              s.emptyLibraryBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
