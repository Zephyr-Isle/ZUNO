import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:zuno/models/library_entry.dart';
import 'package:zuno/models/wallpaper_manifest.dart';
import 'package:zuno/models/wallpaper_type.dart';
import 'package:zuno/wallpaper_package/manifest_validator.dart';
import 'package:zuno/wallpaper_package/path_guard.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';

/// 导入成功结果。
class ImportOutcome {
  const ImportOutcome({required this.entry, required this.manifest});

  final LibraryEntry entry;
  final WallpaperManifest manifest;
}

/// ZIP 导入与校验编排（ZUNO Package v1）。
///
/// 重要：本文件只 import dart:* 与 archive —— 整个函数体是无 Flutter 依赖的纯 Dart，
/// 因此可以被 [Isolate.run] 整体投到后台 isolate 执行（解压大包不阻塞 UI），
/// 返回值是普通对象（Isolate.exit 允许传输任意对象图）。
///
/// 流程（规格固定的校验顺序）：
/// 1. 解压到内存（ZipDecoder），逐条目做路径遍历检查（一票否决）；
/// 2. 定位 manifest.json（根目录或单一顶层文件夹内）；
/// 3. 必填字段完整性 + type 合法性（严格解析）；
/// 4. entry 文件存在性 + content/ 非空 + minSdk + 类型特定检查；
/// 5. timed → schedule + slot 子包递归校验；
/// 6. 解压到暂存目录（忽略 manifest/thumbnail/content 之外的根级文件）；
/// 7. checksum（若声明）按规范重算比对；
/// 8. 原子 rename 进壁纸库 `<libraryRoot>/<id>/`（同 id 覆盖旧版本）。
Future<Object> importZunoPackage({
  required String zipPath,
  required String stagingParentPath,
  required String libraryRootPath,
  required int deviceApiLevel,
}) async {
  final issues = <ValidationIssue>[];

  // ---------- 1. 打开 ZIP（流式解码） ----------
  // 为什么用 InputFileStream + decodeBuffer 而不是 decodeBytes：
  // decodeBytes 会把整个 ZIP 解压进内存（大视频包直接 OOM）；
  // 流式模式下条目内容按需解压，读后立即 clear()，峰值内存 = 最大单文件。
  final zipFile = File(zipPath);
  if (!zipFile.existsSync()) {
    return ImportFailure([
      ValidationIssue(IssueCode.zipInvalid, '文件不存在: $zipPath'),
    ]);
  }
  final InputFileStream zipInput;
  try {
    zipInput = InputFileStream(zipPath);
  } catch (e) {
    return ImportFailure([
      ValidationIssue(IssueCode.zipInvalid, '无法打开 ZIP 文件: $e'),
    ]);
  }
  Archive archive;
  try {
    archive = ZipDecoder().decodeBuffer(zipInput, verify: false);
  } catch (e) {
    zipInput.closeSync();
    return ImportFailure([
      ValidationIssue(IssueCode.zipInvalid, '不是合法的 ZIP 容器: $e'),
    ]);
  }

  try {
    // 归一化条目名。遇到路径遍历条目立即整包拒绝（防 Zip Slip）。
    final entries = <String, ArchiveFile>{};
    // 解压防护上限：条目内容是按需解压进内存的（峰值内存 = 最大单文件），
    // 恶意包声明一个解压后几十 GB 的条目会在 compute isolate 里直接 OOM
    // 带崩进程。size 来自 ZIP 中央目录，检查零解压成本；现实中的视频包
    // 在数百 MB 级，1 GiB 单条目 / 2 GiB 总量远超合法边界。
    var entryCount = 0;
    var totalBytes = 0;
    for (final entry in archive) {
      entryCount++;
      if (entryCount > _maxEntryCount) {
        return ImportFailure([
          const ValidationIssue(
            IssueCode.zipInvalid,
            '拒绝导入：ZIP 条目数超过上限（疑似 zip bomb）',
          ),
        ]);
      }
      final safe = PathGuard.sanitize(entry.name);
      if (safe == null) {
        return ImportFailure([
          ValidationIssue(
            IssueCode.zipSlip,
            '拒绝导入：条目 "${entry.name}" 含路径遍历/绝对路径',
          ),
        ]);
      }
      if (!entry.isFile) continue;
      final size = entry.size;
      if (size < 0 || size > _maxEntryBytes) {
        return ImportFailure([
          ValidationIssue(
            IssueCode.zipInvalid,
            '拒绝导入：条目 "${entry.name}" 解压后超过 $_maxEntryBytes 字节上限（疑似 zip bomb）',
          ),
        ]);
      }
      totalBytes += size;
      if (totalBytes > _maxTotalBytes) {
        return ImportFailure([
          const ValidationIssue(
            IssueCode.zipInvalid,
            '拒绝导入：ZIP 解压总量超过上限（疑似 zip bomb）',
          ),
        ]);
      }
      entries.putIfAbsent(safe, () => entry);
    }
    if (entries.isEmpty) {
      return ImportFailure([
        const ValidationIssue(IssueCode.zipInvalid, 'ZIP 中没有任何文件'),
      ]);
    }

    // 读取条目内容并立刻释放缓存（读后即弃，内存只保留当前这一份）。
    List<int> readAndClear(ArchiveFile f) {
      final bytes = f.content as List<int>;
      f.clear();
      return bytes;
    }

    // ---------- 2. 定位 manifest.json（根目录或单一顶层文件夹） ----------
    var basePrefix = '';
    if (entries.containsKey('manifest.json')) {
      basePrefix = '';
    } else {
      final topLevelWithManifest = <String>{};
      for (final p in entries.keys) {
        final parts = p.split('/');
        if (parts.length == 2 && parts[1] == 'manifest.json') {
          topLevelWithManifest.add(parts[0]);
        }
      }
      if (topLevelWithManifest.length == 1) {
        basePrefix = '${topLevelWithManifest.first}/';
      } else if (topLevelWithManifest.isEmpty) {
        return ImportFailure([
          const ValidationIssue(
            IssueCode.manifestMissing,
            '根目录（或单一顶层文件夹内）没有 manifest.json',
          ),
        ]);
      } else {
        return ImportFailure([
          ValidationIssue(
            IssueCode.manifestMissing,
            '存在多个顶层文件夹含 manifest.json：${topLevelWithManifest.join(', ')}',
          ),
        ]);
      }
    }

    /// 把归一化路径映射为“包内路径”（去掉顶层文件夹前缀）。
    String inner(String p) =>
        basePrefix.isEmpty ? p : p.substring(basePrefix.length);
    final packageFiles = entries.keys.map(inner).toSet();

    /// 按包内路径读取条目字节（读后释放缓存）。缺失路径由调用方先行判定。
    List<int> readPackageFile(String packagePath) {
      final f = entries[basePrefix + packagePath];
      if (f == null) {
        throw StateError('package file missing: $packagePath');
      }
      return readAndClear(f);
    }

    // ---------- 3. manifest 字段校验 ----------
    final dynamic manifestRaw;
    try {
      manifestRaw = jsonDecode(
        utf8.decode(readPackageFile('manifest.json'), allowMalformed: true),
      );
    } catch (e) {
      return ImportFailure([
        ValidationIssue(
          IssueCode.manifestUnreadable,
          'manifest.json 不是合法 JSON: $e',
        ),
      ]);
    }
    if (manifestRaw is! Map) {
      return ImportFailure([
        const ValidationIssue(
          IssueCode.manifestUnreadable,
          'manifest.json 顶层必须是对象',
        ),
      ]);
    }
    final manifest = ManifestValidator.validateFields(
      Map<String, dynamic>.from(manifestRaw),
      issues,
    );
    if (manifest == null) return ImportFailure(issues);

    // ---------- 4. 结构校验 ----------
    ManifestValidator.validateStructure(
      manifest: manifest,
      files: packageFiles,
      issues: issues,
      deviceApiLevel: deviceApiLevel,
    );
    if (issues.isNotEmpty) return ImportFailure(issues);

    // ---------- 5. timed 递归校验 ----------
    TimedPackageInfo? timedInfo;
    if (manifest.type == WallpaperType.timed) {
      if (!packageFiles.contains('content/schedule.json')) {
        issues.add(
          const ValidationIssue(
            IssueCode.timedScheduleInvalid,
            'timed 包必须包含 content/schedule.json',
          ),
        );
        return ImportFailure(issues);
      }
      timedInfo = ManifestValidator.validateTimed(
        manifest: manifest,
        files: packageFiles,
        scheduleBytes: readPackageFile('content/schedule.json'),
        readFile: readPackageFile,
        issues: issues,
      );
      if (timedInfo == null) return ImportFailure(issues);
    }

    // ---------- 6. 解压到暂存目录（忽略规格外的根级文件） ----------
    final staging = Directory(
      '$stagingParentPath/${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(0x7FFFFFFF)}',
    );
    try {
      await staging.create(recursive: true);
      for (final e in entries.entries) {
        final pkgPath = inner(e.key);
        if (!_isAllowedRootEntry(pkgPath)) continue; // 规格外的根级文件忽略
        final f = File('${staging.path}/$pkgPath'); // Dart IO 接受 '/' 分隔
        await f.create(recursive: true);
        await f.writeAsBytes(readAndClear(e.value));
      }

      // 解压后的磁盘路径再次做 canonical 校验（PathGuard 双保险的另一半）。
      for (final entity in staging.listSync(recursive: true)) {
        if (entity is File && !PathGuard.isInside(staging, entity)) {
          return ImportFailure([
            const ValidationIssue(IssueCode.zipSlip, '解压后的路径逃逸出暂存目录'),
          ]);
        }
      }

      // ---------- 7. checksum ----------
      if (manifest.checksum != null) {
        await ManifestValidator.validateChecksum(
          extractedPackageDir: staging,
          expected: manifest.checksum!,
          issues: issues,
        );
        if (issues.isNotEmpty) return ImportFailure(issues);
      }

      // ---------- 8. 原子 rename 进壁纸库（同 id 覆盖） ----------
      // 目标父目录必须存在（rename 不会自动创建）。
      await Directory(libraryRootPath).create(recursive: true);
      // 纵深防御：以 canonical 化的库根为基、拼接 manifest 白名单 id
      // （id 已拒绝 "."/".." 且不含路径分隔符），两者组合保证 rename 目标
      // 不可能逃出壁纸库；不存在的目标目录不能做 realpath 校验，故用此组合判定。
      final libraryCanonical = Directory(libraryRootPath)
          .resolveSymbolicLinksSync();
      final finalDirPath = '$libraryCanonical/${manifest.id}';
      final finalDir = Directory(finalDirPath);
      if (finalDir.existsSync()) {
        await finalDir.delete(recursive: true);
      }
      await staging.rename(finalDirPath);

      final entry = _buildEntry(
        manifest: manifest,
        packageDirPath: finalDirPath,
        packageFiles: packageFiles,
        timedInfo: timedInfo,
      );
      return ImportOutcome(entry: entry, manifest: manifest);
    } catch (e) {
      issues.add(ValidationIssue(IssueCode.unknown, '导入过程异常: $e'));
      return ImportFailure(issues);
    } finally {
      // rename 成功后暂存目录已不存在；失败时清理现场。
      if (staging.existsSync()) {
        await staging.delete(recursive: true).catchError((_) => staging);
      }
    }
  } finally {
    // 释放全部条目缓存并关闭 ZIP 文件句柄（所有 return 路径都会经过这里；
    // 解码失败路径已在上方提前返回并关闭句柄）。
    for (final f in archive) {
      f.clear();
    }
    zipInput.closeSync();
  }
}

bool _isAllowedRootEntry(String packagePath) {
  return packagePath == 'manifest.json' ||
      packagePath == 'thumbnail.png' ||
      packagePath.startsWith('content/');
}

LibraryEntry _buildEntry({
  required WallpaperManifest manifest,
  required String packageDirPath,
  required Set<String> packageFiles,
  required TimedPackageInfo? timedInfo,
}) {
  return LibraryEntry(
    id: manifest.id,
    version: manifest.version,
    title: manifest.title,
    authorHandle: manifest.author?.handle,
    type: manifest.type.wire,
    packageDir: packageDirPath,
    entry: manifest.entry,
    thumbnailPath: packageFiles.contains('thumbnail.png')
        ? '$packageDirPath/thumbnail.png'
        : null,
    performanceHint: manifest.performanceHint,
    configParams: manifest.config.map((c) => c.toMap()).toList(),
    capabilities: manifest.capabilities.toMap(),
    installedAt: DateTime.now().millisecondsSinceEpoch,
    scheduleRules: timedInfo?.rules ?? const [],
    scheduleDefaultSlot: timedInfo?.defaultSlot ?? '',
    slotIds: timedInfo?.slotIds ?? const [],
  );
}

final Random _rand = Random();

/// 解压防护上限（见 importZunoPackage 步骤 1 的说明）。
const int _maxEntryCount = 10000;
const int _maxEntryBytes = 1 << 30; // 1 GiB
const int _maxTotalBytes = 2 << 30; // 2 GiB
