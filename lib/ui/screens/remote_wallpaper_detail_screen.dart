import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/models/remote_wallpaper.dart';
import 'package:zuno/services/remote_api.dart';
import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/ui/screens/wallpaper_detail_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/type_badge.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';

/// 在线壁纸详情：元数据 + 下载导入（无需登录）。
///
/// 用独立页面而不是底部弹层：下载需要固定的主 CTA，而 `GlassModalSheet`
/// 本身就是玻璃面，再塞一个玻璃按钮就是双重折射（设计规范明确禁止）。
class RemoteWallpaperDetailScreen extends StatefulWidget {
  const RemoteWallpaperDetailScreen({
    super.key,
    required this.item,
    required this.catalog,
    required this.library,
  });

  final RemoteWallpaper item;
  final CatalogController catalog;
  final LibraryController library;

  @override
  State<RemoteWallpaperDetailScreen> createState() =>
      _RemoteWallpaperDetailScreenState();
}

class _RemoteWallpaperDetailScreenState
    extends State<RemoteWallpaperDetailScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    File? file;
    try {
      // 匿名下载：不传 token，服务端记 uid=anon 并照常签发票据。
      file = await widget.catalog.download(widget.item);
      final entry = await widget.library.importFromPath(file.path);
      if (!mounted) return;
      if (entry == null) {
        final result = widget.library.lastImportResult;
        if (result is ImportFailure) {
          _showIssues(result);
        } else {
          lgw.GlassToast.show(
            context,
            message: widget.library.importing
                ? '已有导入正在进行，请稍候'
                : '导入失败：下载的文件无法读取',
            type: lgw.GlassToastType.error,
          );
        }
        return;
      }
      lgw.GlassToast.show(
        context,
        message: '已加入「我的壁纸」',
        type: lgw.GlassToastType.success,
      );
      // 与本地导入保持一致：成功后直达详情页，应用壁纸是自然的下一步。
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WallpaperDetailScreen(
            controller: widget.library,
            entry: entry,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '下载失败：$error');
    } finally {
      // 临时包已经解压进壁纸库，源文件没有保留价值。
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {
          // 删不掉就交给系统缓存回收。
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showIssues(ImportFailure failure) {
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
                  '导入被拒绝',
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
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    // extendBody 后内容滚进玻璃栏下方由 soft 边缘淡出收尾；
    // ListView 自己让出 app bar 与底部下载 CTA 的高度。
    final mediaQuery = MediaQuery.of(context);

    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: Text(item.title),
        centerTitle: false,
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: '返回',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Material(
        type: MaterialType.transparency,
        child: ListView(
          // 顶部让出状态栏 + app bar；底部让出 bottomBar CTA（76）与安全区。
          padding: EdgeInsets.fromLTRB(
            16,
            mediaQuery.padding.top + 44 + 12,
            16,
            mediaQuery.padding.bottom + 76 + 16,
          ),
          children: [
            GlassSurface(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  appIcon(AppIcons.cloud, size: 34, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TypeBadge(type: item.type),
                ],
              ),
            ),
            const SizedBox(height: 14),
            lgw.GlassGroupedSection(
              header: const Text('包信息'),
              // 纯文字行卡走 solid：premium 玻璃的雾会把行文字糊掉。
              surfaceStyle: lgw.GlassSurfaceStyle.solid,
              shape: glassShape(radius: 28),
              children: [
                _row(context, AppIcons.user, '作者',
                    (item.author == null || item.author!.isEmpty)
                        ? '未署名'
                        : item.author!),
                _row(context, AppIcons.layers, '版本', 'v${item.version}'),
                _row(context, AppIcons.database, '大小', item.sizeLabel),
                _row(context, AppIcons.clock, '更新', item.updatedLabel),
                _row(context, AppIcons.info, '标识', item.id),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  appIcon(AppIcons.error, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12.5, color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '下载后会在本机重新校验 manifest 与 checksum，'
                '通过校验才会进入「我的壁纸」；不通过时会把具体原因列出来。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomBar: ListenableBuilder(
        listenable: widget.catalog,
        builder: (context, _) {
          final downloading = widget.catalog.isDownloading(item.id);
          final progress = widget.catalog.progressOf(item.id);
          final String label;
          if (_busy || downloading) {
            label = progress == null
                ? '下载中…'
                : '下载中 ${(progress * 100).round()}%';
          } else {
            label = '下载并导入';
          }
          return PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: GlassPrimaryButton(
                icon: AppIcons.download,
                label: label,
                onPressed: (_busy || downloading) ? () {} : _download,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppIconData icon,
    String label,
    String value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return lgw.GlassListTile(
      leading: appIcon(icon),
      leadingIconColor: scheme.primary,
      title: Text(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
