import 'dart:convert';
import 'dart:io';

import 'package:zuno/models/wallpaper_manifest.dart';
import 'package:zuno/models/wallpaper_type.dart';
import 'package:zuno/wallpaper_package/checksum.dart';
import 'package:zuno/wallpaper_package/timed_schedule.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';

/// manifest 与包结构的校验器（ZUNO Package v1 校验规则摘要）。
///
/// 顺序（规格固定，任何一步失败整包拒绝）：
/// 路径遍历检查 → manifest.json 存在性 → 必填字段完整性 → type 合法性
/// → entry 文件存在性 → content/ 非空 → checksum 比对（若存在）
/// → timed 的子壁纸 manifest 递归校验。
///
/// 前六步发生在解压前（基于 ZIP 条目名集合），后两步发生在解压后（基于磁盘目录），
/// 因为 checksum 必须按规范重新计算解压后的字节。
class ManifestValidator {
  ManifestValidator._();

  /// 第 3 步：必填字段完整性 + type 合法性（交给严格解析器，异常转 issue）。
  /// 兜底捕获一切解析异常（如包作者构造的畸形结构触发 TypeError），
  /// 保证“畸形包 = 校验失败”，绝不向上抛异常打断导入流程。
  static WallpaperManifest? validateFields(
    Map<String, dynamic> raw,
    List<ValidationIssue> issues,
  ) {
    try {
      return WallpaperManifest.parse(raw);
    } on ManifestFormatException catch (e) {
      issues.add(ValidationIssue(IssueCode.fieldInvalid, e.toString()));
      return null;
    } catch (t) {
      issues.add(
        ValidationIssue(IssueCode.fieldInvalid, 'manifest 解析异常（包结构畸形）: $t'),
      );
      return null;
    }
  }

  /// 第 4–6 步：entry 存在性、content/ 非空、minSdk、depth/html 的类型特定检查。
  /// [files] 为归一化后的 ZIP 相对路径集合（已去 basePrefix 的“包内路径”）。
  static void validateStructure({
    required WallpaperManifest manifest,
    required Set<String> files,
    required List<ValidationIssue> issues,
    required int deviceApiLevel,
  }) {
    // entry 指向的文件必须真实存在于包内。
    if (!files.contains(manifest.entry)) {
      issues.add(
        ValidationIssue(
          IssueCode.entryMissing,
          'entry "${manifest.entry}" 不在包内（包内文件 ${files.length} 个）',
        ),
      );
    }
    // content/ 必须存在且非空（规格）。
    final contentFiles = files
        .where((f) => f.startsWith('content/') && f.length > 'content/'.length)
        .toList();
    if (contentFiles.isEmpty) {
      issues.add(
        const ValidationIssue(
          IssueCode.contentEmpty,
          'content/ 目录为空（或 ZIP 中未包含 content/ 条目）',
        ),
      );
    }
    // minSdk 不得高于当前设备。
    if (manifest.minSdk > deviceApiLevel) {
      issues.add(
        ValidationIssue(
          IssueCode.minSdkTooHigh,
          '包要求 minSdk=${manifest.minSdk}，本机 API=$deviceApiLevel',
        ),
      );
    }
    switch (manifest.type) {
      case WallpaperType.depth:
        // 深度壁纸的渲染器固定读取 content/depth.png（见 DepthWallpaperEngine）。
        if (!files.contains('content/depth.png')) {
          issues.add(
            const ValidationIssue(
              IssueCode.fieldInvalid,
              'depth 类型要求包内存在 content/depth.png（与 color 同尺寸的灰度深度图）',
            ),
          );
        }
        // entry 指向的颜色图必须是常见图片格式。
        final entryExt = manifest.entry.split('.').last.toLowerCase();
        if (!const {'jpg', 'jpeg', 'png'}.contains(entryExt)) {
          issues.add(
            ValidationIssue(
              IssueCode.fieldInvalid,
              'depth 类型的 entry 应为 jpg/png，实际: ${manifest.entry}',
            ),
          );
        }
      case WallpaperType.html:
        final entryExt = manifest.entry.split('.').last.toLowerCase();
        if (entryExt != 'html' && entryExt != 'htm') {
          issues.add(
            ValidationIssue(
              IssueCode.fieldInvalid,
              'html 类型的 entry 应为 .html 文件，实际: ${manifest.entry}',
            ),
          );
        }
      case WallpaperType.video:
        final entryExt = manifest.entry.split('.').last.toLowerCase();
        if (!const {'mp4', 'webm'}.contains(entryExt)) {
          issues.add(
            ValidationIssue(
              IssueCode.fieldInvalid,
              'video 类型的 entry 应为 mp4/webm，实际: ${manifest.entry}',
            ),
          );
        }
      case WallpaperType.timed:
        // schedule 结构与 slot 引用在 validateTimed 中处理。
        break;
    }
  }

  /// 第 7 步：checksum 比对（解压后按规范重算）。
  static Future<void> validateChecksum({
    required Directory extractedPackageDir,
    required String expected,
    required List<ValidationIssue> issues,
  }) async {
    try {
      final actual = await PackageChecksum.compute(extractedPackageDir);
      if (!PackageChecksum.verify(expected, actual)) {
        issues.add(
          ValidationIssue(
            IssueCode.checksumMismatch,
            '校验和不匹配：期望 $expected，实际计算 $actual',
          ),
        );
      }
    } on FileSystemException catch (e) {
      issues.add(
        ValidationIssue(IssueCode.checksumMismatch, '重算校验和失败: ${e.message}'),
      );
    }
  }

  /// 第 8 步：timed 递归校验（schedule 解析 + 每个 slot 子包 manifest 的完整校验）。
  ///
  /// [readFile] 提供按包内路径读取 ZIP 条目字节的回调（由 importer 注入），
  /// 使本函数可以递归校验 slot 子 manifest 的内容而不必先解压。
  /// 成功返回解析出的调度信息（写入壁纸库索引），失败时 issues 非空。
  static TimedPackageInfo? validateTimed({
    required WallpaperManifest manifest,
    required Set<String> files,
    required List<int> scheduleBytes,
    required List<int> Function(String packagePath) readFile,
    required List<ValidationIssue> issues,
  }) {
    final (schedule, errors) = TimedScheduleParser.parse(
      utf8.decode(scheduleBytes, allowMalformed: true),
    );
    if (schedule == null || errors.isNotEmpty) {
      for (final e in errors) {
        issues.add(ValidationIssue(IssueCode.timedScheduleInvalid, e));
      }
      return null;
    }

    final referenced = <String>{
      ...schedule.rules.map((r) => r.slotName),
      if (schedule.defaultSlot.isNotEmpty) schedule.defaultSlot,
    };
    final slotIds = <String>[];
    for (final slotName in referenced) {
      final slotRoot = 'content/$slotName';
      final slotManifestPath = '$slotRoot/manifest.json';
      if (!files.contains(slotManifestPath)) {
        issues.add(
          ValidationIssue(
            IssueCode.timedSlotMissing,
            'schedule 引用的 slot "$slotName" 不存在（缺少 $slotManifestPath）',
          ),
        );
        continue;
      }
      // slot 内容非空（规格：slot_* 目录内结构遵循某一 type，含自己的 content/）。
      final slotContentPrefix = '$slotRoot/content/';
      final hasContent = files.any(
        (f) =>
            f.startsWith(slotContentPrefix) &&
            f.length > slotContentPrefix.length,
      );
      if (!hasContent) {
        issues.add(
          ValidationIssue(
            IssueCode.timedSlotInvalid,
            'slot "$slotName" 的 content/ 为空',
          ),
        );
        continue;
      }
      // slot 子 manifest：只要求最简字段（schemaVersion/id/type/entry），
      // entry 指向的文件必须真实存在，type 不允许嵌套 timed。
      try {
        final raw = Map<String, dynamic>.from(
          jsonDecode(
            utf8.decode(readFile(slotManifestPath), allowMalformed: true),
          ) as Map,
        );
        final subSchema = raw['schemaVersion'];
        final subId = raw['id'];
        final subType = raw['type'];
        final subEntry = raw['entry'];
        if (subSchema != 1) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 的 manifest.schemaVersion 必须为 1',
            ),
          );
          continue;
        }
        if (subId is! String || subId.isEmpty) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 的 manifest.id 缺失',
            ),
          );
          continue;
        }
        if (subId == manifest.id) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 的 id 与顶层包 id 冲突',
            ),
          );
          continue;
        }
        if (subType == 'timed') {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 不允许嵌套 timed 类型',
            ),
          );
          continue;
        }
        if (subType is! String ||
            !const {'video', 'html', 'depth'}.contains(subType)) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 的 type 必须是 video/html/depth，实际: $subType',
            ),
          );
          continue;
        }
        if (subEntry is! String || subEntry.isEmpty) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotInvalid,
              'slot "$slotName" 的 manifest.entry 缺失',
            ),
          );
          continue;
        }
        final entryPath = '$slotRoot/$subEntry';
        if (!files.contains(entryPath)) {
          issues.add(
            ValidationIssue(
              IssueCode.timedSlotMissing,
              'slot "$slotName" 的 entry "$subEntry" 不存在',
            ),
          );
          continue;
        }
        slotIds.add(slotName);
      } catch (e) {
        issues.add(
          ValidationIssue(
            IssueCode.timedSlotInvalid,
            'slot "$slotName" 的 manifest.json 无法解析: $e',
          ),
        );
      }
    }
    if (issues.isNotEmpty) return null;
    return TimedPackageInfo(
      rules: schedule.rules.map((r) => r.toMap()).toList(),
      defaultSlot: schedule.defaultSlot,
      slotIds: slotIds.toList(),
      chargingOnly: schedule.chargingOnly,
      minIntervalMinutes: schedule.minIntervalMinutes,
    );
  }
}

/// timed 校验通过后的派生信息（写入壁纸库索引，供 UI 展示与运行时参考）。
class TimedPackageInfo {
  const TimedPackageInfo({
    required this.rules,
    required this.defaultSlot,
    required this.slotIds,
    required this.chargingOnly,
    required this.minIntervalMinutes,
  });

  final List<Map<String, dynamic>> rules;
  final String defaultSlot;
  final List<String> slotIds;
  final bool chargingOnly;
  final int minIntervalMinutes;
}
