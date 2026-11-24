import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/models/remote_wallpaper.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/type_badge.dart';

/// 在线壁纸库的网格卡片。
///
/// 与本地 [PackageCard] 同一套玻璃形态（圆角 28、玻璃承载信息区），
/// 但后端不下发封面图（只给 id 与元数据），所以上半部分用类型语义色
/// 的渐层占位图 + 类型图标，靠色相区分 video / html / depth / timed。
class RemotePackageCard extends StatefulWidget {
  const RemotePackageCard({
    super.key,
    required this.item,
    required this.onTap,
    this.downloading = false,
    this.progress,
    this.installed = false,
    this.coverUrl,
  });

  final RemoteWallpaper item;
  final VoidCallback onTap;

  /// 服务端封面地址（`/api/wallpapers/:id/cover`）；null 时用类型占位图。
  final String? coverUrl;

  /// 下载中：占位图上叠进度环，点击仍然可用（详情页会阻止重复下载）。
  final bool downloading;

  /// 0–1；null 表示服务端没给 Content-Length，显示不确定进度环。
  final double? progress;

  /// 本地库里已有同 id 的包（含旧版本）。
  final bool installed;

  @override
  State<RemotePackageCard> createState() => _RemotePackageCardState();
}

class _RemotePackageCardState extends State<RemotePackageCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    final s = ZunoLocalizations.of(context);
    final visual = _visualOf(item.type);
    return Semantics(
      button: true,
      label: '${s.wallpaperLibrary}: ${item.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: lgw.GlassContainer.card(
            shape: glassShape(radius: 28),
            padding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            quality: lgw.GlassQuality.premium,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 占位图始终铺底：封面加载中/失败时不会露出空白。
                      _placeholder(context, visual),
                      if (widget.coverUrl != null)
                        Image.network(
                          widget.coverUrl!,
                          fit: BoxFit.cover,
                          // 封面是 480×800 的预览图，限制解码内存避免列表滚动卡顿。
                          cacheWidth: 480,
                          // 失败时保持底层占位图即可，不显示错误图标。
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) return child;
                            return const SizedBox.shrink();
                          },
                        ),
                      if (widget.downloading) _progressOverlay(context, scheme),
                      if (widget.installed)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                appIcon(
                                  AppIcons.check,
                                  size: 11,
                                  color: scheme.onPrimary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  s.installed,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TypeBadge(type: item.type),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'v${item.version}',
                          if (item.author != null && item.author!.isNotEmpty)
                            item.author!,
                          item.sizeLabel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, _TypeVisual visual) {
    final base = zunoThumbnailPlaceholder(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              visual.color.withValues(alpha: 0.22),
              base,
            ),
            base,
          ],
        ),
      ),
      child: Center(
        child: appIcon(
          visual.icon,
          size: 40,
          color: visual.color.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _progressOverlay(BuildContext context, ColorScheme scheme) {
    final percent = widget.progress;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 34,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              percent == null
                  ? ZunoLocalizations.of(context).downloading
                  : '${(percent * 100).round()}%',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeVisual {
  const _TypeVisual(this.icon, this.color);

  final AppIconData icon;
  final Color color;
}

/// 类型 → 图标与语义色。色值与 [TypeBadge] 保持同一套（浅色主题基准），
/// 占位图上用低透明度，深浅主题都不会突兀。
_TypeVisual _visualOf(String type) => switch (type) {
  'video' => const _TypeVisual(AppIcons.video, Color(0xFF5B4BE0)),
  'html' => const _TypeVisual(AppIcons.image, Color(0xFF0B8578)),
  'depth' => const _TypeVisual(AppIcons.layers, Color(0xFF1D6FE0)),
  'timed' => const _TypeVisual(AppIcons.clock, Color(0xFFB45309)),
  _ => const _TypeVisual(AppIcons.wallpaper, Color(0xFF6E6E73)),
};
