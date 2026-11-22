import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zuno/core/zuno_paths.dart';
import 'package:zuno/models/library_entry.dart';
import 'package:zuno/services/library_repository.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/wallpaper_applier.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';
import 'package:zuno/wallpaper_package/zip_exporter.dart';
import 'package:zuno/wallpaper_package/zip_importer.dart';

/// 壁纸库状态管理（管理端 UI 的唯一数据源）。
class LibraryController extends ChangeNotifier {
  LibraryController(this._repository, this._deviceApiLevel);

  final LibraryRepository _repository;
  final int _deviceApiLevel;
  final WallpaperApplier _applier = const WallpaperApplier();

  List<LibraryEntry> _entries = [];
  Map<String, dynamic>? _activeWallpaper;
  bool _liveWallpaperActive = false;
  bool _importing = false;

  /// 最近一次导入的完整结果（ImportOutcome | ImportFailure），
  /// UI 据此展示校验失败报告。
  Object? lastImportResult;

  /// 最近一次导入产生的非致命提醒（如视频编码不在规格支持列表）。
  List<String> lastImportWarnings = const [];

  List<LibraryEntry> get entries => List.unmodifiable(_entries);
  Map<String, dynamic>? get activeWallpaper => _activeWallpaper;
  String? get activeId => _activeWallpaper?['id'] as String?;
  bool get liveWallpaperActive => _liveWallpaperActive;
  bool get importing => _importing;

  /// 该条目是否正在被系统壁纸使用。
  ///
  /// timed 父包要特殊判断：激活记录里的 id 是其某个 slot 子包的 id，
  /// 与父包 id 永不相等——只比较 id 会让正在使用的 timed 包永远不显示
  /// “使用中”，还允许用户把它删掉导致壁纸悬空。父目录一致即视为使用中。
  bool isEntryActive(LibraryEntry entry) {
    if (activeId == entry.id) return true;
    final parent = _activeWallpaper?['timedParentDir'] as String?;
    return parent != null && parent == entry.packageDir;
  }

  /// 启动 / 回到前台时刷新（用户可能刚在系统预览页改了激活状态）。
  Future<void> refresh() async {
    _entries = _repository.getAll();
    _activeWallpaper = await ZunoNative.getActiveWallpaper();
    _liveWallpaperActive = await ZunoNative.isLiveWallpaperActive();
    notifyListeners();
  }

  /// 选择 .zuno 壁纸包并在后台 isolate 中导入。
  ///
  /// 返回新导入的条目（成功）；取消 / 校验失败返回 null——失败详情见
  /// [lastImportResult]。
  ///
  /// 解压与校验是 CPU/IO 密集操作，放在 isolate 中执行以避免阻塞 UI
  /// （规格明确要求在 isolate 中解压）。compute 会把闭包与参数一并投到
  /// 后台 isolate，返回值通过 Isolate.exit 传输（支持任意对象图）。
  Future<LibraryEntry?> importPackage() async {
    // 让用户挑 .zuno / .zip（.zuno 本质是 ZIP，桌面管理端同样两种都列出；
    // 有的包作者会以 .zip 分发）。file_picker 13.x 静态入口，取消时返回空
    // 列表。用 FileType.custom + allowedExtensions 按扩展名过滤；少数 ROM
    // 的 SAF 会禁用自定义扩展名条目，此时仍可切到“文件”视图选择。选择层
    // 的过滤只是体验优化，真正的安全边界是下面 Isolate 里的完整内容校验
    // （路径遍历 / manifest / checksum），非法文件照样会被拒绝并给出原因。
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zuno', 'zip'],
    );
    final path = files.isNotEmpty ? files.first.path : null;
    if (path == null) {
      // 用户取消：清掉上一次的失败报告，避免主界面把旧报告当成本次结果弹出。
      lastImportResult = null;
      return null;
    }

    return importFromPath(path);
  }

  /// 导入串行链：所有导入（手动选择 / 云端下载完成后）排在同一条链上依次
  /// 执行。此前并发触发（下载完成时用户恰好也在手动导入）第二个会直接
  /// 返回 null——远端详情页拿不到条目还会把刚下载的整包删掉，重试要再付
  /// 一次完整下载的流量；排队则让已下载的包自然被消费。
  Future<LibraryEntry?> _importChain = Future.value(null);

  /// 从已知路径导入（在线壁纸库下载完成后走这里）。
  ///
  /// 和 [importPackage] 共用同一套 isolate 校验：下载来的包同样可能损坏，
  /// 不能因为“来自自家服务器”就跳过路径遍历 / manifest / checksum 检查。
  Future<LibraryEntry?> importFromPath(String path) {
    final task = _importChain.then((_) => _importNow(path));
    // 链不能被单次失败打断：吞掉错误（结果已通过 lastImportResult 暴露）。
    _importChain = task.then((_) => null, onError: (Object _) => null);
    return task;
  }

  Future<LibraryEntry?> _importNow(String path) async {
    _importing = true;
    notifyListeners();
    try {
      final stagingParent = (await ZunoPaths.stagingRoot()).path;
      final libraryRoot = (await ZunoPaths.libraryRoot()).path;
      Object? result;
      try {
        result = await compute(
          _importInIsolate,
          _ImportArgs(
            zipPath: path,
            stagingParentPath: stagingParent,
            libraryRootPath: libraryRoot,
            deviceApiLevel: _deviceApiLevel,
          ),
        );
      } catch (e) {
        // isolate 内未预料的异常（如设备存储故障）也转为可展示的失败报告，
        // 不能让未处理异步异常逃出 UI 调用链。
        result = ImportFailure([
          ValidationIssue(IssueCode.unknown, '导入过程异常: $e'),
        ]);
      }
      lastImportResult = result;
      lastImportWarnings = const [];
      if (result is ImportOutcome) {
        var entry = result.entry;
        // 包作者没提供 thumbnail.png 时自动生成缩略图：
        // video/depth → 原生取首帧/缩放颜色图；html → 原生沙箱 WebView 离屏
        // 截图（与壁纸渲染同一套实现）；timed 父包无单一画面，保持占位。
        if (entry.thumbnailPath == null) {
          try {
            String? thumb;
            if (entry.type == 'video' || entry.type == 'depth') {
              thumb = await ZunoNative.ensureThumbnail(
                dir: entry.packageDir,
                type: entry.type,
                entryPath: entry.entry,
                outPath: '${entry.packageDir}/thumbnail.jpg',
              );
            } else if (entry.type == 'html') {
              thumb = await ZunoNative.ensureHtmlThumbnail(
                dir: entry.packageDir,
                entryPath: entry.entry,
                outPath: '${entry.packageDir}/thumbnail.jpg',
              );
            }
            if (thumb != null) {
              entry = entry.copyWith(thumbnailPath: thumb);
            }
          } catch (_) {
            // 缩略图失败不影响导入结果。
          }
        }
        // 视频能力探测（导入期）：两条独立警告 ——
        // 1) 编码不在常用列表（H.264/H.265 之外的编码依赖设备支持）；
        // 2) 解码器能力超限（如 4K60 的 H.264 High 5.2，ExoPlayer 报
        //    NO_EXCEEDS_CAPABILITIES，预览黑屏、壁纸只能降级静态首帧）。
        if (entry.type == 'video') {
          final videoPath = '${entry.packageDir}/${entry.entry}';
          final mime = await ZunoNative.probeVideoCodec(path: videoPath);
          const supported = {
            'video/avc',
            'video/hevc',
            'video/h263',
            'video/mp4v-es',
          };
          final warnings = <String>[];
          if (mime != null && !supported.contains(mime)) {
            warnings.add(
              '此视频的编码格式在部分手机上可能不支持：'
              '壁纸可能显示为静态画面，建议换用 H.264/H.265 编码的视频',
            );
          }
          final decodable = await ZunoNative.probeVideoSupported(
            path: videoPath,
          );
          if (decodable == false) {
            warnings.add(
              '此视频的分辨率/帧率超出本机解码能力：'
              '预览与壁纸将显示为静态首帧',
            );
          }
          lastImportWarnings = warnings;
        }
        await _repository.put(entry);
        await refresh();
        return entry;
      }
      return null;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  /// 应用壁纸（写激活状态 + 拉起系统预览确认）。返回 null 表示成功，
  /// 否则为用户可读的错误/提示信息。
  Future<String?> apply(
    LibraryEntry entry,
    Map<String, Object?> configValues,
  ) async {
    try {
      final result = await _applier.apply(entry, configValues);
      await refresh();
      if (!result.success) {
        return result.message ?? '应用失败';
      }
      // 激活状态已写入；但系统选择器可能没有打开（两个 Intent 都失败的 ROM），
      // 此时必须告诉用户手动路径，不能谎称“预览页即将打开”。
      return result.previewLaunched
          ? null
          : '已保存壁纸设置，但未能打开系统预览——请在系统设置的壁纸页中手动选择 ZUNO';
    } catch (e) {
      return '应用失败: $e';
    }
  }

  /// 导出壁纸包为 .zuno 文件（流式打包，峰值内存 = 最大单文件的编码缓冲）。
  /// 返回导出文件路径；失败返回 null。
  ///
  /// 包文件自导入后不会被 ZUNO 改动（用户参数在 SharedPreferences，
  /// 不在包文件里），因此 manifest 内的 checksum 导出后依然有效——
  /// 导出的包可直接再导入（同 id 覆盖语义）。
  Future<String?> exportEntry(LibraryEntry entry) async {
    try {
      final tmp = await getTemporaryDirectory();
      final outDir = Directory('${tmp.path}/exports');
      await outDir.create(recursive: true);
      // 去掉 id 里的点造成的前后缀歧义：com.a.b → com_a_b。
      final safeId = entry.id.replaceAll('.', '_');
      final outPath = '${outDir.path}/${safeId}_${entry.version}.zuno';
      final ok = await compute(
        _exportInIsolate,
        _ExportArgs(packageDir: entry.packageDir, outPath: outPath),
      );
      return ok ? outPath : null;
    } catch (_) {
      return null;
    }
  }

  /// 删除壁纸包。正在被系统壁纸使用（含 timed 父包）的包拒绝删除。
  Future<String?> delete(LibraryEntry entry) async {
    if (isEntryActive(entry)) {
      return '该壁纸正在使用中，请先应用其他壁纸再删除';
    }
    try {
      final dir = Directory(entry.packageDir);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
      await _repository.delete(entry.id);
      await refresh();
      return null;
    } catch (e) {
      return '删除失败: $e';
    }
  }

  /// timed 预览：在指定时刻激活对应 slot（不拉起系统选择器，
  /// ZUNO 已是活跃组件时引擎静默热切换）。返回 slot id。
  ///
  /// 守卫：只在“当前激活的就是本 timed 包（或其 slot）”时执行。预览的本质是
  /// 写激活记录 + ConfigBus 热切换——若激活的是别的壁纸，无条件写入会把它顶掉：
  /// 引擎立刻改渲染 timed 的子壁纸，而原壁纸在 UI 上失去“使用中”标记，
  /// 状态与画面就此分叉。非激活时返回 null（UI 禁用滑杆并给出提示）。
  Future<String?> previewTimedSlot(LibraryEntry entry, int minutesOfDay) async {
    if (!isEntryActive(entry)) return null;
    try {
      return await _applier.previewTimedSlot(entry, minutesOfDay);
    } catch (_) {
      return null;
    }
  }

  /// 把 timed 壁纸的激活 slot 立即恢复为设备当前时间对应的时段。
  ///
  /// 离开详情页时调用：预览语义是“临时的”，此前要等 WorkManager 下次调度
  /// 检查（最长 15 分钟）才回正，期间壁纸一直停留在用户拖动的模拟时刻。
  /// 复用 [previewTimedSlot]（含 isEntryActive 守卫与异常吞掉），fire-and-forget。
  Future<void> restoreTimedSlotNow(LibraryEntry entry) async {
    final now = DateTime.now();
    await previewTimedSlot(entry, now.hour * 60 + now.minute);
  }

  /// 打开原生沙箱预览（HTML）。预览与壁纸渲染共用同一套 WebView 沙箱实现。
  Future<void> openHtmlPreview(
    LibraryEntry entry,
    Map<String, Object?> configValues,
  ) async {
    await ZunoNative.openHtmlPreview(
      dir: entry.packageDir,
      entry: entry.entry,
      configJson: jsonEncode(configValues),
    );
  }
}

/// isolate 入口的参数包（compute 要求单一参数）。
class _ImportArgs {
  const _ImportArgs({
    required this.zipPath,
    required this.stagingParentPath,
    required this.libraryRootPath,
    required this.deviceApiLevel,
  });

  final String zipPath;
  final String stagingParentPath;
  final String libraryRootPath;
  final int deviceApiLevel;
}

/// 顶层函数：isolate 入口必须是顶层/静态函数。
Future<Object> _importInIsolate(_ImportArgs args) {
  return importZunoPackage(
    zipPath: args.zipPath,
    stagingParentPath: args.stagingParentPath,
    libraryRootPath: args.libraryRootPath,
    deviceApiLevel: args.deviceApiLevel,
  );
}

/// 导出 isolate 的参数包。
class _ExportArgs {
  const _ExportArgs({required this.packageDir, required this.outPath});

  final String packageDir;
  final String outPath;
}

/// 顶层函数：流式打包包目录为 .zuno（STORE 之外的压缩交给 ZipEncoder 默认策略）。
///
/// 用 `ArchiveFile.stream` + `ZipEncoder.startEncode/addFile/endEncode` 全程流式：
/// 大视频包导出时峰值内存只有编码缓冲，不会整包进内存。
Future<bool> _exportInIsolate(_ExportArgs args) {
  return exportPackageToZip(packageDir: args.packageDir, outPath: args.outPath);
}
