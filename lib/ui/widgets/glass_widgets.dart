import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/ui/widgets/app_icons.dart';

/// ZUNO 液态玻璃组件集（基于 `liquid_glass_widgets`，iOS 27 材质）。
///
/// 设计基准是 Apple 的浅色 Liquid Glass：
/// - 页面背景是干净的浅灰紫，不再使用深空渐变/星点；玻璃的折射来自
///   白色卡片、蓝色主色和页面内容本身
/// - 玻璃只出现在控制层（导航、按钮、壁纸卡片）；纯文字/信息卡走
///   `GlassSurfaceStyle.solid` 平实卡面（原生 iOS 分组卡形态），不吃
///   玻璃雾；不要在玻璃容器里再塞玻璃控件（双重折射，包内明确禁止）
/// - 主 CTA 固定在 `GlassScaffold.bottomBar`，不放在滚动列表里：
///   `premium` 玻璃会捕获背景纹理，滚动时放在列表内会出现背景“消失”
/// - 图标按钮统一用 [GlassCircleButton]：正方形约束 + 关闭锚点拉伸，
///   避免胶囊/椭圆化
///
/// 包以 `lgw` 前缀导入，避免与 ZUNO wrapper 重名。

/// 全应用统一的页面底色：接近 iOS 分组列表的浅灰紫。
const Color zunoPageBackground = Color(0xFFF5F4FA);

/// 深色模式的页面底色：比纯黑略浅、保留同款灰紫冷调，玻璃才有折射层次。
const Color zunoPageBackgroundDark = Color(0xFF0C0B10);

/// 全应用统一的强调色：与导入 / 应用 CTA 的主蓝完全一致。
/// 主按钮、`ColorScheme.primary`、滑杆与选中态都只能用它，别再引入第二种蓝。
const Color zunoAccent = Color(0xFF007AFF);

/// 当前主题亮度下的状态栏图标样式（浅色底 → 深色图标）。
/// 不能用 `GlassStatusBarStyle.auto`：它跟随系统亮度，App 内强制主题时会相反。
lgw.GlassStatusBarStyle zunoStatusBarStyle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? lgw.GlassStatusBarStyle.light
    : lgw.GlassStatusBarStyle.dark;

/// 缩略图缺失时的占位底色（跟随明暗主题）。
Color zunoThumbnailPlaceholder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF232228)
    : const Color(0xFFE9E8F1);

/// 统一的玻璃形状：superellipse 连续曲率（iOS 原生圆角形态）。
lgw.LiquidShape glassShape({double radius = 26}) =>
    lgw.LiquidRoundedSuperellipse(borderRadius: radius);

/// 文字/信息面板卡：iOS 原生 inset-grouped 的平实不透明卡面。
///
/// 纯文字卡片不适合玻璃：iOS 27 premium 的 frost 雾会把卡面文字糊成
/// “雾中残影”（发雾），滚动中玻璃捕获的背景失效还会发灰发白。原生
/// 设置页的分组卡本来就是平实表面（`GlassSurfaceStyle.solid`，零
/// shader、零背景捕获）；玻璃只留给导航栏 / TAB / 按钮这类控制层。
/// 圆角 28 与全局玻璃主题一致。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return lgw.GlassContainer.card(
      shape: glassShape(radius: borderRadius),
      padding: padding,
      surfaceStyle: lgw.GlassSurfaceStyle.solid,
      child: child,
    );
  }
}

/// 玻璃圆形图标按钮：导航栏/工具栏里的图标控制。
///
/// 外层强制正方形、关闭 `anchorStretch`：这是之前圆形按钮被按扁/拉成
/// 椭圆的根因。`premium` + 独立图层只为少数导航按钮服务，开销可控。
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.semanticLabel,
  });

  final AppIconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: lgw.GlassIconButton(
        icon: appIcon(icon),
        onPressed: onPressed,
        size: size,
        iconSize: size * 0.44,
        shape: lgw.GlassIconButtonShape.circle,
        quality: lgw.GlassQuality.premium,
        useOwnLayer: true,
        anchorStretch: false,
        interactionScale: 0.94,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// 玻璃主操作按钮：应用壁纸 / 导入等主 CTA。
///
/// [accent] = true 时使用系统蓝玻璃 + 白字（相当于 Apple 的
/// `.prominentGlass` 主按钮）；false 时是普通透明玻璃 + 深色文字。
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.accent = true,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = accent ? Colors.white : scheme.onSurface;
    return lgw.GlassButton.custom(
      onTap: onPressed,
      width: double.infinity,
      height: height,
      shape: glassShape(radius: height / 2),
      style: accent
          ? lgw.GlassButtonStyle.prominent
          : lgw.GlassButtonStyle.filled,
      settings: accent
          ? const lgw.LiquidGlassSettings(
              // clear 模式保留设计色值，不会被自适应亮度改成青色；
              // 这是 Apple prominent 主按钮的系统蓝。
              glassColor: zunoAccent,
              bodyMode: lgw.GlassBodyMode.clear,
              thickness: 30,
              lightIntensity: 0.24,
              chromaticAberration: 0.03,
              saturation: 1.0,
            )
          : null,
      quality: lgw.GlassQuality.premium,
      useOwnLayer: true,
      glowColor: accent
          ? zunoAccent.withValues(alpha: 0.4)
          : scheme.primary.withValues(alpha: 0.24),
      glowRadius: 1.4,
      // FittedBox：窄屏/大字体时整行等比缩小，不会 RenderFlex overflow，
      // 也不会把按钮文字直接裁成省略号。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(icon, color: foreground, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                // 屏蔽模拟器上系统拼写检查给 CTA 文字画的黄色下划线。
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玻璃次要按钮：详情页“打开实时预览”等轻量操作。
class GlassSecondaryButton extends StatelessWidget {
  const GlassSecondaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.height = 46,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return lgw.GlassButton.custom(
      onTap: onPressed,
      width: double.infinity,
      height: height,
      shape: glassShape(radius: height / 2),
      quality: lgw.GlassQuality.premium,
      // 与 GlassPrimaryButton 一致：每层 premium 玻璃拿独立图层，不共享
      // 页级 backdrop capture，避免滚动/背景变化时丢色。
      useOwnLayer: true,
      glowColor: scheme.primary.withValues(alpha: 0.18),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            appIcon(icon, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
