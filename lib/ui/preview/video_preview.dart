import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:zuno/l10n/zuno_localizations.dart';

/// 视频壁纸的 App 内预览（video_player 软解走 Flutter 纹理）。
///
/// 注意：这只是库管理页的小窗预览。真机壁纸由原生 ExoPlayer（默认硬解、
/// 可切软解）直连 Surface（VideoWallpaperEngine），不经过 Flutter。
class VideoPreview extends StatefulWidget {
  const VideoPreview({
    super.key,
    required this.videoPath,
    this.volume = 0.0,
    this.speed = 1.0,
    this.expand = false,
    this.fallbackImage,
  });

  final String videoPath;

  /// 预览音量与壁纸行为对齐：原生壁纸默认静音（config.volume，默认 0），
  /// 预览也默认静音；用户在参数面板调过音量时由详情页传入实际值。
  final double volume;

  /// 预览播放速度与壁纸行为对齐（config.playback_speed，默认 1.0）。
  final double speed;

  /// true = 填满父容器（全屏预览页用）；false = 详情页内嵌 220px 小窗。
  final bool expand;

  /// 解码失败（如 4K60 超出本机解码能力）时显示的静态首帧图
  /// （包的缩略图，与壁纸引擎的静态首帧降级一致）。
  final String? fallbackImage;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(widget.volume.clamp(0.0, 1.0));
      await controller.setPlaybackSpeed(widget.speed.clamp(0.5, 2.0));
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      _error = ZunoStrings.current.videoPreviewInitFailed(e);
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    // 参数面板调整后实时同步预览（与原生壁纸的 config 联动行为一致）。
    if (widget.volume != oldWidget.volume) {
      controller.setVolume(widget.volume.clamp(0.0, 1.0));
    }
    if (widget.speed != oldWidget.speed) {
      controller.setPlaybackSpeed(widget.speed.clamp(0.5, 2.0));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // expand（全屏页）：填满父约束；内嵌模式：固定 220px 高的小窗。
    Widget frame(Widget child) => widget.expand
        ? SizedBox.expand(child: child)
        : SizedBox(height: 220, child: child);
    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      // 解码失败降级：显示视频首帧（与壁纸引擎的静态首帧行为一致），
      // 附带一句用户可读的原因——不再把 PlatformException 原文甩给用户。
      return frame(
        Stack(
          fit: StackFit.expand,
          children: [
            if (widget.fallbackImage != null)
              Image.file(
                File(widget.fallbackImage!),
                fit: BoxFit.cover,
                cacheWidth: 720,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black),
              )
            else
              const ColoredBox(color: Colors.black),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(
                  _error != null
                      ? ZunoLocalizations.of(context).videoUnsupported
                      : ZunoLocalizations.of(context).videoLoading,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return frame(
      ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
