import 'package:flutter/material.dart';

import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/ui/screens/remote_wallpaper_detail_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/remote_package_card.dart';

/// “壁纸库”页：浏览云端目录，直接下载导入（无需登录）。
///
/// 浏览与下载都不需要账号；后端签名的是 5 分钟票据，不是用户会话。
/// 上传不在这里：那是管理端（ADMIN_SECRET + WebDAV 直传）的职责。
class WallpaperLibraryScreen extends StatefulWidget {
  const WallpaperLibraryScreen({
    super.key,
    required this.catalog,
    required this.library,
    required this.onOpenSettings,
  });

  final CatalogController catalog;
  final LibraryController library;

  /// 空库/连不上时的引导：后端地址在设置页里改。
  final VoidCallback onOpenSettings;

  @override
  State<WallpaperLibraryScreen> createState() => _WallpaperLibraryScreenState();
}

class _WallpaperLibraryScreenState extends State<WallpaperLibraryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 首帧后拉目录：initState 里发请求会在没有 context 的情况下触发
    // notifyListeners → 上层 ListenableBuilder 直接 setState 报错。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.catalog.ensureLoaded();
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // 提前 320px 预取，滚动到底时下一页通常已经就绪。
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.catalog.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外壳 extendBody: true：滚动内容钻进玻璃栏下方，由 soft 边缘淡出
    // 收尾。首屏内容用 padding 让出状态栏 + app bar 与底部玻璃 TAB
    // （barHeight 66 + verticalPadding 18×2 + 底部安全区）。
    final mediaQuery = MediaQuery.of(context);
    final topClear = mediaQuery.padding.top + 44 + 12;
    final bottomClear = 102.0 + mediaQuery.padding.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.catalog, widget.library]),
      builder: (context, _) {
        final catalog = widget.catalog;
        final installed = widget.library.entries.map((e) => e.id).toSet();
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            if (catalog.loading && catalog.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (catalog.error != null && catalog.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: catalog.error!,
                  onRetry: catalog.refresh,
                  onOpenSettings: widget.onOpenSettings,
                ),
              )
            else if (catalog.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onOpenSettings: widget.onOpenSettings),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, topClear, 16, 8),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 210,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.62,
                      ),
                  itemCount: catalog.items.length,
                  itemBuilder: (context, index) {
                    final item = catalog.items[index];
                    return RemotePackageCard(
                      item: item,
                      coverUrl: catalog.coverUrlOf(item),
                      installed: installed.contains(item.id),
                      downloading: catalog.isDownloading(item.id),
                      progress: catalog.progressOf(item.id),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RemoteWallpaperDetailScreen(
                            item: item,
                            catalog: catalog,
                            library: widget.library,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: _Footer(
                  loading: catalog.loading,
                  error: catalog.error,
                  hasMore: catalog.hasMore,
                  onRetry: catalog.loadMore,
                  bottomClear: bottomClear,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
    required this.bottomClear,
  });

  final bool loading;
  final String? error;
  final bool hasMore;
  final VoidCallback onRetry;

  /// 底部让出玻璃 TAB 的高度（含安全区），“到底”提示不钻进 TAB 下面。
  final double bottomClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    if (loading) {
      child = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (error != null) {
      child = TextButton(
        onPressed: onRetry,
        child: Text(error!, textAlign: TextAlign.center),
      );
    } else if (!hasMore) {
      child = Text(
        '已经到底了',
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, bottomClear + 16),
      child: Center(child: child),
    );
  }
}

/// 空库：最常见的两种情况是「后端还没同步」和「地址填错了」，
/// 所以文案把两条路都指出来，并直接给一个进设置页的入口。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // SliverFillRemaining 在整屏（extendBody）里居中：底部让出玻璃 TAB，
    // 文案和按钮才不会撞在 TAB 上。
    final clearBottom = 102.0 + MediaQuery.paddingOf(context).bottom + 24;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, clearBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(AppIcons.cloud, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('壁纸库是空的', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              '如果这是你自己部署的后端，请到「设置 → 壁纸库地址」'
              '填写正确的服务地址；地址正确但列表为空，说明管理端还没有'
              '同步任何 .zuno 包。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 220,
              child: GlassSecondaryButton(
                icon: AppIcons.settings,
                label: '设置壁纸库地址',
                onPressed: onOpenSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clearBottom = 102.0 + MediaQuery.paddingOf(context).bottom + 24;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, clearBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(AppIcons.error, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 14),
            Text('目录加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  child: GlassSecondaryButton(
                    icon: AppIcons.settings,
                    label: '改地址',
                    onPressed: onOpenSettings,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: GlassSecondaryButton(
                    icon: AppIcons.refresh,
                    label: '重试',
                    onPressed: onRetry,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
