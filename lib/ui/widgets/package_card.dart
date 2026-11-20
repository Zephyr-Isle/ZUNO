import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/models/library_entry.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/type_badge.dart';

/// 壁纸库网格卡片。
///
/// 卡片本身就是一块液态玻璃：缩略图覆盖上半部分，信息区直接坐在玻璃上，
/// 边缘保留折射/高光。按压用轻微缩放反馈，不用 Material 水波纹——
/// 水波纹会画在玻璃后面的透明 Material 上，反而看不见。
class PackageCard extends StatefulWidget {
  const PackageCard({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final LibraryEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  State<PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<PackageCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '壁纸 ${entry.title}',
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
            // 卡片内容与"使用中"边框都放在玻璃容器内部：边框与玻璃边缘
            // 共享同一 antiAlias 裁剪和绘制层。此前边框是叠在容器外的独立
            // DecoratedBox——玻璃着色器逐帧重渲染时会把镜头几何做像素对齐，
            // 而容器外的普通绘制不跟着对齐，滚动时边框相对卡片边缘逐帧
            // 漂移（视觉上蓝色边框"变形"）。
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 缩略图存在性交给 errorBuilder 兜底：build 期间做
                          // existsSync 是 UI 线程同步 IO，网格每次滚动重建都对
                          // 磁盘逐卡片探测一次。
                          if (entry.thumbnailPath != null)
                            Image.file(
                              File(entry.thumbnailPath!),
                              fit: BoxFit.cover,
                              // 壁纸包的缩略图建议 480×800；cacheWidth 限制解码内存。
                              cacheWidth: 480,
                              errorBuilder: (_, _, _) =>
                                  _placeholder(context, scheme),
                            )
                          else
                            _placeholder(context, scheme),
                          if (widget.active)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '使用中',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              TypeBadge(type: entry.type),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${entry.version}'
                            '${entry.authorHandle != null ? ' · ${entry.authorHandle}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.active)
                  // 活跃指示边框：必须用与卡片相同的 LiquidRoundedSuperellipse
                  // 超椭圆形状描边——卡片是连续曲率的 squircle，普通
                  // BorderRadius.circular 是 1/4 圆弧，两者四角不吻合，边框会
                  // 像浮在卡片外。内缩 2px、半径同步内收到 26，描边外缘正好
                  // 贴住卡片边缘；ShapeDecoration 走 shape.paint，与玻璃容器
                  // 共享同一条几何路径，不再逐帧漂移。
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: lgw.LiquidRoundedSuperellipse(
                            borderRadius: 26,
                            side: BorderSide(color: scheme.primary, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, ColorScheme scheme) => Container(
    color: zunoThumbnailPlaceholder(context),
    alignment: Alignment.center,
    child: appIcon(
      AppIcons.wallpaper,
      size: 42,
      color: scheme.primary.withValues(alpha: 0.45),
    ),
  );
}
