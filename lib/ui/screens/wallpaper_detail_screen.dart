import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/models/library_entry.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/wallpaper_applier.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/ui/preview/depth_preview.dart';
import 'package:zuno/ui/preview/fullscreen_preview_page.dart';
import 'package:zuno/ui/preview/video_preview.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/config_editor.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';
import 'package:zuno/ui/widgets/type_badge.dart';

/// 壁纸详情：预览、参数编辑、应用、删除。
class WallpaperDetailScreen extends StatefulWidget {
  const WallpaperDetailScreen({
    super.key,
    required this.controller,
    required this.entry,
  });

  final LibraryController controller;
  final LibraryEntry entry;

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  late Map<String, Object?> _configValues;

  // ---------- timed 时段预览滑杆 ----------
  /// null = 跟随实际时间；非 null = 用户选择的模拟时刻（当日分钟数）。
  int? _previewMinutes;

  /// 预览防抖：拖动过程中只更新标签，停止 300ms 后才真正切换 slot。
  Timer? _previewDebounce;

  /// 预览切换后的 slot id（用于标签展示）。
  String? _previewSlotId;

  /// “正在打包”常驻 toast 的关闭句柄（导出完成/失败/离开页面时收起）。
  VoidCallback? _packingToast;

  @override
  void dispose() {
    _dismissPackingToast();
    widget.controller.removeListener(_onControllerChanged);
    _previewDebounce?.cancel();
    // 离开详情页立即把时段恢复为设备实际时间：预览语义是“临时的”，
    // 此前要等 WorkManager 下次调度检查（最长 15 分钟）才回正。
    // fire-and-forget——controller 生命周期长于本页，恢复不依赖页面存活。
    if (_previewMinutes != null) {
      widget.controller.restoreTimedSlotNow(widget.entry);
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 初始值 = 每个参数的 default（应用时可被用户覆盖）。
    _configValues = {
      for (final p in widget.entry.configParams)
        if (p['default'] != null) p['key'] as String: p['default'] as Object?,
    };
    // 已应用过的壁纸：以激活记录里保存的用户配置为初始值。
    // 否则每次打开详情页滑杆都显示 manifest 默认值，用户点“应用”会
    // 把之前调好的参数静默覆盖回默认。
    _loadAppliedConfig();
    // controller 状态变化（apply 后激活记录刷新）驱动重建：timed 预览滑杆的
    // 可用性依赖 isEntryActive，不监听会出现“在本页应用成功后滑杆仍禁用”，
    // 直到下一次任意 setState 才恢复。
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant WallpaperDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  Future<void> _loadAppliedConfig() async {
    final active = await ZunoNative.getActiveWallpaper();
    if (active == null || !mounted) return;
    // timed 包的激活记录 id 是 slot 子包 id，用 timedParentDir 匹配父包。
    final isSame =
        (active['timedParentDir'] as String?) == widget.entry.packageDir ||
        active['id'] == widget.entry.id;
    if (!isSame) return;
    final saved = active['configJson'];
    if (saved is! String || saved.isEmpty || saved == '{}') return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map || !mounted) return;
      setState(() {
        _configValues = {
          ..._configValues,
          for (final e in decoded.entries)
            if (e.key is String) e.key as String: e.value as Object?,
        };
      });
    } catch (_) {
      // 激活记录的 config 损坏时保持默认值，不阻塞详情页。
    }
  }

  Future<void> _apply() async {
    final error = await widget.controller.apply(widget.entry, _configValues);
    if (!mounted) return;
    lgw.GlassToast.show(
      context,
      // 文案尽量短：GlassToast 的气泡宽受 maxWidth 约束，长文案在窄屏/
      // 大字体下会挤到两行上限之外，玻璃层跟着被撑出屏幕（提示气泡溢出）。
      message: error ?? '即将打开系统预览，请点“设置壁纸”',
      type: error == null ? lgw.GlassToastType.info : lgw.GlassToastType.error,
    );
  }

  /// 收回“正在打包”常驻 toast；重复调用安全（句柄先取出再置空）。
  void _dismissPackingToast() {
    final dismiss = _packingToast;
    _packingToast = null;
    dismiss?.call();
  }

  Future<void> _share() async {
    _dismissPackingToast();
    _packingToast = lgw.GlassToast.show(
      context,
      message: '正在打包壁纸包（流式导出）…',
      type: lgw.GlassToastType.info,
      duration: Duration.zero, // 大视频包打包耗时不可预估，完成后手动收起。
      dismissible: false,
    );
    final String? path;
    try {
      path = await widget.controller.exportEntry(widget.entry);
    } finally {
      _dismissPackingToast();
    }
    if (!mounted) return;
    if (path == null) {
      lgw.GlassToast.show(
        context,
        message: '导出失败',
        type: lgw.GlassToastType.error,
      );
      return;
    }
    final launched = await ZunoNative.sharePackage(
      path: path,
      title: widget.entry.title,
    );
    if (!mounted) return;
    if (!launched) {
      lgw.GlassToast.show(
        context,
        message: '已导出到：$path',
        type: lgw.GlassToastType.success,
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await lgw.GlassDialog.show<bool>(
      context: context,
      title: '删除壁纸包？',
      message: '${widget.entry.title} 及其文件将被一并删除。',
      actions: [
        lgw.GlassDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(context, false),
        ),
        lgw.GlassDialogAction(
          label: '删除',
          isDestructive: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed != true) return;
    final error = await widget.controller.delete(widget.entry);
    if (!mounted) return;
    if (error != null) {
      lgw.GlassToast.show(
        context,
        message: error,
        type: lgw.GlassToastType.error,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    // extendBody 后内容滚进玻璃栏下方由 soft 边缘淡出收尾；
    // ListView 自己让出 app bar 与底部 CTA 栏的高度。
    final mediaQuery = MediaQuery.of(context);
    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: Text(entry.title),
        centerTitle: false,
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: '返回',
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          // 导出分享：重新打包为 .zuno（流式），经系统分享面板发出。
          GlassCircleButton(
            icon: AppIcons.share,
            semanticLabel: '导出 / 分享',
            onPressed: _share,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GlassCircleButton(
              icon: AppIcons.delete,
              semanticLabel: '删除',
              onPressed: _delete,
            ),
          ),
        ],
      ),
      body: Material(
        type: MaterialType.transparency,
        child: ListView(
          // 顶部让出状态栏 + app bar；底部让出 bottomBar CTA（110）与安全区。
          padding: EdgeInsets.fromLTRB(
            16,
            mediaQuery.padding.top + 44 + 12,
            16,
            mediaQuery.padding.bottom + 110 + 20,
          ),
          children: [
            // ---------- 预览 ----------
            _preview(),
            const SizedBox(height: 20),

            // ---------- 元信息 ----------
            Row(
              children: [
                TypeBadge(type: entry.type),
                const SizedBox(width: 8),
                Text('v${entry.version}'),
                const Spacer(),
                Text(
                  '性能建议: ${_hintLabel(entry.performanceHint)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (entry.authorHandle != null) ...[
              const SizedBox(height: 4),
              Text(
                '作者: ${entry.authorHandle}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),

            // ---------- 能力声明 ----------
            if (entry.capabilities.isNotEmpty) _capabilities(),

            // ---------- timed 调度 ----------
            if (entry.type == 'timed') ...[
              const SizedBox(height: 8),
              _schedule(),
              const SizedBox(height: 8),
              _timedPreviewSlider(),
            ],

            const SizedBox(height: 20),

            // ---------- 可调参数 ----------
            if (entry.configParams.isNotEmpty) ...[
              Text('参数', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // 参数卡片用 solid（白底）而不是玻璃：里面的滑杆/开关本身是
              // 液态玻璃控件，玻璃套玻璃会产生双重折射。白底也正好对应
              // 参考图里承载控件的 iOS 卡片。
              lgw.GlassContainer.card(
                surfaceStyle: lgw.GlassSurfaceStyle.solid,
                shape: glassShape(radius: 28),
                padding: const EdgeInsets.all(16),
                child: ConfigEditor(
                  params: entry.configParams,
                  values: _configValues,
                  onChanged: (v) => setState(() => _configValues = v),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      // 主 CTA 固定在底部栏：滑动列表时按钮和它的玻璃背景都不动，
      // 不会再出现“越滚背景越透明/消失”。
      bottomBar: PreferredSize(
        // 文案允许两行：窄屏/大字体下不再溢出或被截断。
        preferredSize: const Size.fromHeight(110),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '点击后打开系统壁纸预览，点“设置壁纸”确认生效',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              // 玻璃按钮固定在不滚动的 bottomBar：放进滚动列表会被滚动手势
              // 触发 LiquidStretch 形变，premium 背景捕获滚动时也会丢色。
              if (entry.type == 'html')
                Row(
                  children: [
                    Expanded(
                      child: GlassSecondaryButton(
                        icon: AppIcons.externalLink,
                        label: '实时预览',
                        onPressed: () => widget.controller.openHtmlPreview(
                          entry,
                          _configValues,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassPrimaryButton(
                        icon: AppIcons.check,
                        label: '应用此壁纸',
                        onPressed: _apply,
                      ),
                    ),
                  ],
                )
              else
                GlassPrimaryButton(
                  icon: AppIcons.check,
                  label: '应用此壁纸',
                  onPressed: _apply,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 给内嵌预览叠一个“进入全屏”悬浮按钮（右上角）。
  ///
  /// SizedBox(width: infinity)：Stack 的 loose 约束会让 FittedBox 类预览
  /// shrink-wrap 到内容原始尺寸（视频缩成封面帧小块），强制撑满列表宽度。
  Widget _withFullscreenButton(Widget child, VoidCallback onOpen) {
    return Stack(
      children: [
        SizedBox(width: double.infinity, child: child),
        Positioned(
          top: 8,
          right: 8,
          child: FullscreenEnterButton(onTap: onOpen),
        ),
      ],
    );
  }

  /// timed 全屏预览：解析当前时段的 slot，展示其真实内容——
  /// video/depth 实时预览；html 打开原生沙箱全屏（与壁纸渲染同一实现，
  /// 原生页自带退出按钮）；解析失败给出提示。
  Future<void> _openTimedFullscreen() async {
    final slot = await ZunoNative.resolveTimedSlot(widget.entry.packageDir);
    if (!mounted) return;
    if (slot == null) {
      lgw.GlassToast.show(
        context,
        message: '未能解析当前时段的子壁纸',
        type: lgw.GlassToastType.error,
      );
      return;
    }
    final dir = slot['slotDir'] as String? ?? '';
    final entryPath = slot['entry'] as String? ?? '';
    final name = slot['slotName'] as String? ?? slot['slotId'] as String? ?? '';
    switch (slot['type'] as String?) {
      case 'video':
        await FullscreenPreviewPage.show(
          context,
          title: '当前时段: $name',
          child: VideoPreview(videoPath: '$dir/$entryPath', expand: true),
        );
      case 'depth':
        await FullscreenPreviewPage.show(
          context,
          title: '当前时段: $name',
          child: DepthPreview(colorPath: '$dir/$entryPath', expand: true),
        );
      case 'html':
        // 实时渲染走原生沙箱页（含退出按钮），不经 Flutter WebView。
        await ZunoNative.openHtmlPreview(
          dir: dir,
          entry: entryPath,
          configJson: '{}',
        );
      default:
        lgw.GlassToast.show(
          context,
          message: '当前时段（$name）不支持全屏预览',
          type: lgw.GlassToastType.warning,
        );
    }
  }

  Widget _preview() {
    final entry = widget.entry;
    switch (entry.type) {
      case 'video':
        return _withFullscreenButton(
          VideoPreview(
            videoPath: '${entry.packageDir}/${entry.entry}',
            // 预览音量/速度与壁纸渲染行为一致（原生按 config 应用于 MediaPlayer）。
            volume: (_configValues['volume'] as num?)?.toDouble() ?? 0.0,
            speed: (_configValues['playback_speed'] as num?)?.toDouble() ?? 1.0,
            // 解码超限（4K60 等）时降级显示首帧，与壁纸引擎的静态降级一致。
            fallbackImage: entry.thumbnailPath,
          ),
          () => FullscreenPreviewPage.show(
            context,
            title: '视频全屏预览',
            child: VideoPreview(
              videoPath: '${entry.packageDir}/${entry.entry}',
              volume: (_configValues['volume'] as num?)?.toDouble() ?? 0.0,
              speed:
                  (_configValues['playback_speed'] as num?)?.toDouble() ?? 1.0,
              fallbackImage: entry.thumbnailPath,
              expand: true,
            ),
          ),
        );
      case 'depth':
        return _withFullscreenButton(
          DepthPreview(
            colorPath: '${entry.packageDir}/${entry.entry}',
            // 预览位移幅度随视差强度参数缩放（0.06 → 24px 基准）。
            strength:
                (_configValues['parallax_strength'] as num?)?.toDouble() ??
                0.06,
          ),
          () => FullscreenPreviewPage.show(
            context,
            title: '深度视差全屏预览',
            child: DepthPreview(
              colorPath: '${entry.packageDir}/${entry.entry}',
              strength:
                  (_configValues['parallax_strength'] as num?)?.toDouble() ??
                  0.06,
              expand: true,
            ),
          ),
        );
      case 'html':
        return Column(
          children: [
            // 缩略图缺失/加载失败统一由 errorBuilder 兜底（build 路径零同步 IO）。
            // 缩略图 = 原生沙箱 WebView 的真实渲染截图：全屏页可放大查看，
            // 实时交互仍走下方“打开沙箱预览”。
            if (entry.thumbnailPath != null)
              _withFullscreenButton(
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(entry.thumbnailPath!),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 480,
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      alignment: Alignment.center,
                      color: Colors.black,
                      child: const Text('无缩略图'),
                    ),
                  ),
                ),
                () => FullscreenPreviewPage.show(
                  context,
                  title: 'HTML 壁纸预览（可捏合缩放）',
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: Image.file(
                        File(entry.thumbnailPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black,
                          child: Center(child: Text('缩略图加载失败')),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 220,
                alignment: Alignment.center,
                color: Colors.black,
                child: const Text('无缩略图'),
              ),
            // “打开实时预览”已移到固定的 bottomBar：它留在滚动列表里时，
            // premium 玻璃会被滚动手势经 LiquidStretch 拉成椭圆（形变），
            // 页级背景捕获滚动时还会失效丢色。
          ],
        );
      case 'timed':
        return _withFullscreenButton(
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                appIcon(AppIcons.clock, color: Colors.white70),
                const SizedBox(height: 8),
                Text(
                  'timed 类型本身不渲染。\n全屏预览将展示当前时段激活的子壁纸。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          _openTimedFullscreen,
        );
      default:
        return const SizedBox(height: 120);
    }
  }

  Widget _capabilities() {
    final caps = widget.entry.capabilities;
    final chips = <String>[
      if (caps['pointer'] == true) '接收触摸',
      if ((caps['sensors'] as List?)?.isNotEmpty == true)
        '传感器: ${(caps['sensors'] as List).join(', ')}',
      if ((caps['network'] as List?)?.isNotEmpty == true) '声明网络（v1 实现仍禁网）',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (c) => lgw.GlassChip(
              label: c,
              // 纯文字能力标签走 solid：premium 的 stretch 即便关了
              // anchorStretch，滚动手势仍会按 X/Y 独立缩放把 chip 拉成椭圆，
              // 且逐帧 shader 会把文字糊成雾；solid 不构造 stretch/shader。
              surfaceStyle: lgw.GlassSurfaceStyle.solid,
            ),
          )
          .toList(),
    );
  }

  Widget _schedule() {
    final entry = widget.entry;
    final current =
        _previewSlotId ??
        WallpaperApplier.currentTimedSlotName(entry) ??
        entry.scheduleDefaultSlot;
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('调度窗口', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              // Flexible + ellipsis：slot 名异常长时不把标题挤出屏幕。
              Flexible(
                child: Text(
                  current.isNotEmpty ? '当前: $current' : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in entry.scheduleRules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${r['from']} – ${r['to']} → ${r['wallpaper']}'),
            ),
          if (entry.scheduleDefaultSlot.isNotEmpty)
            Text('默认: ${entry.scheduleDefaultSlot}'),
        ],
      ),
    );
  }

  /// timed 时段预览滑杆：拖动改变模拟时刻，300ms 防抖后激活对应 slot，
  /// 壁纸引擎经 ConfigBus 热切换。下次调度检查时恢复实际时段。
  /// 仅在本包已激活（系统壁纸正用它）时可拖：预览会写激活记录热切换，
  /// 激活别的壁纸时滑动会把它顶掉（见 [LibraryController.previewTimedSlot]）。
  Widget _timedPreviewSlider() {
    final minutes = _previewMinutes ?? _nowMinutes();
    final hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final mm = (minutes % 60).toString().padLeft(2, '0');
    final canPreview = widget.controller.isEntryActive(widget.entry);
    final scheme = Theme.of(context).colorScheme;
    // 白底卡片 + 玻璃滑杆：滑杆是液态玻璃控件，外层不能再用玻璃容器。
    return lgw.GlassContainer.card(
      surfaceStyle: lgw.GlassSurfaceStyle.solid,
      shape: glassShape(radius: 28),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('时段预览', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              // Flexible + ellipsis：防长 slot 名把标题挤出屏幕。
              Flexible(
                child: Text(
                  '$hh:$mm'
                  '${_previewSlotId != null ? ' → $_previewSlotId' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _previewMinutes != null
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          lgw.GlassSlider(
            value: minutes.toDouble(),
            min: 0,
            max: 1439,
            divisions: 1439,
            activeColor: scheme.primary,
            inactiveColor: scheme.primary.withValues(alpha: 0.16),
            thumbColor: Colors.white,
            quality: lgw.GlassQuality.premium,
            useOwnLayer: true,
            onChanged: canPreview
                ? (v) {
                    setState(() => _previewMinutes = v.round());
                  }
                : null,
            onChangeEnd: canPreview
                ? (v) => _applyPreviewSlot(v.round())
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            canPreview
                ? '拖动预览各时段的壁纸效果；'
                      '实际时段由 WorkManager 在下次调度检查时恢复。'
                : '应用此壁纸后才能预览时段切换'
                      '（预览会热切换激活的子壁纸）。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  int _nowMinutes() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  void _applyPreviewSlot(int minutes) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final slotId = await widget.controller.previewTimedSlot(
          widget.entry,
          minutes,
        );
        if (!mounted) return;
        setState(() => _previewSlotId = slotId);
      } catch (_) {
        // 预览失败静默处理（下一次拖动会重试）。
      }
    });
  }

  String _hintLabel(String hint) => switch (hint) {
    'low' => '低',
    'high' => '高',
    _ => '中',
  };
}
