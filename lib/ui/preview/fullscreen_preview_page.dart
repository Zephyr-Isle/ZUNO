import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zuno/l10n/zuno_localizations.dart';
import 'package:zuno/ui/widgets/app_icons.dart';

/// 全屏预览页：沉浸式黑底容器，任意预览内容填满其中。
///
/// - 进入时隐藏状态栏/导航栏（immersive sticky），退出时恢复系统 UI；
/// - 右上角常驻悬浮“退出”按钮（半透明圆底，任何背景上可见）；
/// - 系统返回手势同样可退出；
/// - [title] 可选：左上角胶囊说明（如“当前时段: slot_day”）。
class FullscreenPreviewPage extends StatefulWidget {
  const FullscreenPreviewPage({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  /// 淡入推入全屏页。
  static Future<void> show(
    BuildContext context, {
    required Widget child,
    String? title,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) =>
            FullscreenPreviewPage(title: title, child: child),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<FullscreenPreviewPage> createState() => _FullscreenPreviewPageState();
}

class _FullscreenPreviewPageState extends State<FullscreenPreviewPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 恢复系统 UI：应用其余页面依赖正常的状态栏布局。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: RoundIconButton(
                icon: AppIcons.close,
                tooltip: ZunoLocalizations.of(context).exitFullscreen,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (widget.title != null)
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 圆形半透明悬浮图标按钮：全屏页的“退出”与内嵌预览的“进入全屏”共用。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.size = 40,
    this.iconSize = 18,
  });

  final AppIconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          shape: const CircleBorder(),
          // Material 的 shape 只负责背景/墨水：不裁切时 InkWell 的方形
          // 命中区域会在视觉上露出直角，按钮看起来像圆角方块。
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: appIcon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// 内嵌预览右上角的“进入全屏”悬浮按钮。
class FullscreenEnterButton extends StatelessWidget {
  const FullscreenEnterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 内嵌在壁纸预览上：按钮和图标都比全屏页的退出键小一档，
    // 否则在缩略图右上角显得笨重、压住画面。
    return RoundIconButton(
      icon: AppIcons.fullscreen,
      tooltip: ZunoLocalizations.of(context).fullscreenPreview,
      onTap: onTap,
      size: 34,
      iconSize: 14,
    );
  }
}
