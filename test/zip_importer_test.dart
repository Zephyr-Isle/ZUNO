import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/l10n/zuno_strings.dart';
import 'package:zuno/wallpaper_package/manifest_validator.dart';
import 'package:zuno/wallpaper_package/path_guard.dart';
import 'package:zuno/wallpaper_package/timed_schedule.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';
import 'package:zuno/wallpaper_package/zip_importer.dart';

/// 导入与校验的单元测试：在临时目录中真实执行完整的 ZIP → 校验 → 入库流程。
///
/// 覆盖规格的校验规则摘要：
/// 路径遍历检查 → manifest.json 存在性 → 必填字段完整性 → type 合法性
/// → entry 文件存在性 → content/ 非空 → checksum → timed 递归校验。
void main() {
  late Directory tempRoot;

  setUp(() async {
    ZunoStrings.current = ZunoStrings.forLanguage('zh');
    tempRoot = await Directory.systemTemp.createTemp('zuno_test_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  // ---------- 造包工具 ----------

  String validHtmlManifest({String? checksum, String type = 'html'}) =>
      jsonEncode({
        'schemaVersion': 1,
        'id': 'com.test.html',
        'version': '1.0.0',
        'title': 'Test HTML',
        'type': type,
        'entry': 'content/index.html',
        'minSdk': 24,
        'checksum': ?checksum,
        'capabilities': {'network': [], 'pointer': true, 'sensors': []},
      });

  String validDepthManifest() => jsonEncode({
    'schemaVersion': 1,
    'id': 'com.test.depth',
    'version': '1.0.0',
    'title': 'Test Depth',
    'type': 'depth',
    'entry': 'content/color.jpg',
    'minSdk': 24,
  });

  List<int> fakePng([String marker = 'png']) =>
      utf8.encode('fake-png-bytes-$marker'); // 校验只看存在性，不看真实图像头

  String timedManifest() => jsonEncode({
    'schemaVersion': 1,
    'id': 'com.test.timed',
    'version': '1.0.0',
    'title': 'Test Timed',
    'type': 'timed',
    'entry': 'content/schedule.json',
    'minSdk': 24,
  });

  String timedSchedule() => jsonEncode({
    'rules': [
      {'from': '06:00', 'to': '18:00', 'wallpaper': 'slot_day'},
      {'from': '18:00', 'to': '06:00', 'wallpaper': 'slot_night'},
    ],
    'default': 'slot_night',
    'constraints': {'chargingOnly': false, 'minIntervalMinutes': 30},
  });

  String slotManifest(String id) => jsonEncode({
    'schemaVersion': 1,
    'id': id,
    'type': 'depth',
    'entry': 'content/color.jpg',
  });

  Future<String> writeZip(Map<String, List<int>> files, String name) async {
    final path = '${tempRoot.path}/$name';
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);
    return path;
  }

  Future<Object> runImport(String zipPath) {
    return importZunoPackage(
      zipPath: zipPath,
      stagingParentPath: tempRoot.path,
      libraryRootPath: '${tempRoot.path}/library',
      deviceApiLevel: 34,
    );
  }

  // ---------- 快乐路径 ----------

  test('html 包完整导入成功', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validHtmlManifest()),
      'thumbnail.png': fakePng('thumb'),
      'content/index.html': utf8.encode('<html><body>hi</body></html>'),
      'content/assets/style.css': utf8.encode('body{color:#fff}'),
    }, 'ok.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportOutcome>());
    final outcome = result as ImportOutcome;

    expect(outcome.manifest.id, 'com.test.html');
    expect(outcome.entry.packageDir, endsWith('library/com.test.html'));
    expect(outcome.entry.thumbnailPath, isNotNull);
    expect(outcome.entry.capabilities['pointer'], true);

    // 文件确实落库。
    expect(
      File('${outcome.entry.packageDir}/content/index.html').existsSync(),
      isTrue,
    );
    // 规格外根级文件被忽略（本包没有；加一个验证忽略行为）。
  });

  test('timed 包完整导入成功（slot 递归校验通过）', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(timedManifest()),
      'content/schedule.json': utf8.encode(timedSchedule()),
      'content/slot_day/manifest.json': utf8.encode(
        slotManifest('com.test.timed.day'),
      ),
      'content/slot_day/content/color.jpg': fakePng('day'),
      'content/slot_day/content/depth.png': fakePng('day-depth'),
      'content/slot_night/manifest.json': utf8.encode(
        slotManifest('com.test.timed.night'),
      ),
      'content/slot_night/content/color.jpg': fakePng('night'),
      'content/slot_night/content/depth.png': fakePng('night-depth'),
    }, 'timed.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportOutcome>());
    final outcome = result as ImportOutcome;
    expect(outcome.entry.slotIds, containsAll(['slot_day', 'slot_night']));
    expect(outcome.entry.scheduleDefaultSlot, 'slot_night');
    expect(outcome.entry.scheduleRules, hasLength(2));
  });

  // ---------- 拒绝路径 ----------

  test('拒绝：manifest.json 缺失（多个顶层文件夹且无 manifest）', () async {
    final zip = await writeZip({
      'a/index.html': utf8.encode('<html></html>'),
      'b/index.html': utf8.encode('<html></html>'),
    }, 'no_manifest.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    final failure = result as ImportFailure;
    expect(
      failure.issues.any((i) => i.message.contains('manifest.json')),
      isTrue,
    );
  });

  test('拒绝：路径遍历条目（../）整包拒绝', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validHtmlManifest()),
      'content/index.html': utf8.encode('<html></html>'),
      'content/../../evil.txt': utf8.encode('evil'),
    }, 'zipslip.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('路径遍历')),
      isTrue,
    );
  });

  test('拒绝：type 非法', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validHtmlManifest(type: 'flash')),
      'content/index.html': utf8.encode('<html></html>'),
    }, 'bad_type.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
  });

  test('拒绝：entry 文件不存在', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validHtmlManifest()),
      'content/not-index.html': utf8.encode('<html></html>'),
    }, 'missing_entry.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('entry')),
      isTrue,
    );
  });

  test('拒绝：depth 包缺少 content/depth.png', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validDepthManifest()),
      'content/color.jpg': fakePng('color'),
    }, 'no_depth.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any(
        (i) => i.message.contains('depth.png'),
      ),
      isTrue,
    );
  });

  test('拒绝：checksum 不匹配', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(validHtmlManifest(checksum: 'sha256-0000')),
      'content/index.html': utf8.encode('<html></html>'),
    }, 'bad_checksum.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('校验和')),
      isTrue,
    );
  });

  test('拒绝：minSdk 高于设备', () async {
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'id': 'com.test.high',
      'version': '1.0.0',
      'title': 'Too New',
      'type': 'html',
      'entry': 'content/index.html',
      'minSdk': 40,
    });
    final zip = await writeZip({
      'manifest.json': utf8.encode(manifest),
      'content/index.html': utf8.encode('<html></html>'),
    }, 'minsdk.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('minSdk')),
      isTrue,
    );
  });

  test('拒绝：id 为 ".."（路径遍历原语，防包目录逃逸）', () async {
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'id': '..',
      'version': '1.0.0',
      'title': 'Traversal',
      'type': 'html',
      'entry': 'content/index.html',
      'minSdk': 24,
    });
    final zip = await writeZip({
      'manifest.json': utf8.encode(manifest),
      'content/index.html': utf8.encode('<html></html>'),
    }, 'id_traversal.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('id')),
      isTrue,
    );
    // 目标目录绝不能被创建到壁纸库之外。
    expect(Directory('${tempRoot.path}/library').existsSync(), isFalse);
  });

  test('拒绝：capabilities 元素类型非法（防 TypeError 逃过校验层）', () async {
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'id': 'com.test.badcaps',
      'version': '1.0.0',
      'title': 'Bad Caps',
      'type': 'html',
      'entry': 'content/index.html',
      'minSdk': 24,
      'capabilities': {
        'network': [1, 2],
      },
    });
    final zip = await writeZip({
      'manifest.json': utf8.encode(manifest),
      'content/index.html': utf8.encode('<html></html>'),
    }, 'bad_caps.zip');

    final result = await runImport(zip);
    // 畸形包必须是“校验失败”，而不是导入流程崩溃。
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any(
        (i) => i.message.contains('capabilities.network'),
      ),
      isTrue,
    );
  });

  test('拒绝：timed 引用的 slot 不存在', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(timedManifest()),
      'content/schedule.json': utf8.encode(timedSchedule()),
      'content/slot_day/manifest.json': utf8.encode(
        slotManifest('com.test.timed.day'),
      ),
      'content/slot_day/content/color.jpg': fakePng('day'),
      'content/slot_day/content/depth.png': fakePng('day-depth'),
      // slot_night 整个缺失
    }, 'timed_missing_slot.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any(
        (i) => i.message.contains('slot_night'),
      ),
      isTrue,
    );
  });

  test('拒绝：slot manifest 的 id 与顶层包 id 冲突', () async {
    final zip = await writeZip({
      'manifest.json': utf8.encode(timedManifest()),
      'content/schedule.json': utf8.encode(timedSchedule()),
      'content/slot_day/manifest.json': utf8.encode(
        slotManifest('com.test.timed'),
      ),
      'content/slot_day/content/color.jpg': fakePng('day'),
      'content/slot_day/content/depth.png': fakePng('day-depth'),
      'content/slot_night/manifest.json': utf8.encode(
        slotManifest('com.test.timed.night'),
      ),
      'content/slot_night/content/color.jpg': fakePng('night'),
      'content/slot_night/content/depth.png': fakePng('night-depth'),
    }, 'timed_id_conflict.zip');

    final result = await runImport(zip);
    expect(result, isA<ImportFailure>());
    expect(
      (result as ImportFailure).issues.any((i) => i.message.contains('冲突')),
      isTrue,
    );
  });

  // ---------- 解压防护（zip bomb） ----------

  // ArchiveFile(name, size, content)：size > 0 时作为"声明解压体积"写入
  // ZIP 头（ZipEncoder: uncompressedSize = file.size），因此可以只分配几字节
  // 内容就伪造出解压后上 GB 的条目，验证上限防护的三个分支。
  test('拒绝：单条目解压体积超过 1 GiB 上限（zip bomb）', () async {
    // ArchiveFile(name, size, content)：size > 0 时作为"声明解压体积"写入
    // ZIP 头（ZipEncoder: uncompressedSize = file.size），因此只需分配几字节
    // 内容就能伪造出解压后上 GB 的条目，零内存成本验证上限防护。
    final path = '${tempRoot.path}/bomb_entry.zip';
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', utf8.encode(validHtmlManifest()).length,
          utf8.encode(validHtmlManifest())))
      ..addFile(ArchiveFile('content/index.html', 14, utf8.encode('<html></html>')))
      ..addFile(ArchiveFile('content/bomb.bin', 2 << 30, utf8.encode('x')));
    File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);

    final result = await runImport(path);
    expect(result, isA<ImportFailure>());
    final failure = result as ImportFailure;
    expect(
      failure.issues.any((i) => i.code == IssueCode.zipInvalid && i.message.contains('zip bomb')),
      isTrue,
      reason: '实际结果: ${failure.issues.map((i) => i.message)}',
    );
  });

  test('拒绝：ZIP 解压总量超过 2 GiB 上限（多条目各自低于单条目上限）', () async {
    final path = '${tempRoot.path}/bomb_total.zip';
    final manifest = utf8.encode(validHtmlManifest());
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest))
      // 每条正好 1 GiB（不触发单条目上限），合计 3 GiB 触发总量上限。
      ..addFile(ArchiveFile('content/a.bin', 1 << 30, utf8.encode('a')))
      ..addFile(ArchiveFile('content/b.bin', 1 << 30, utf8.encode('b')))
      ..addFile(ArchiveFile('content/c.bin', 1 << 30, utf8.encode('c')));
    File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);

    final result = await runImport(path);
    expect(result, isA<ImportFailure>());
    final failure = result as ImportFailure;
    expect(
      failure.issues.any((i) => i.code == IssueCode.zipInvalid && i.message.contains('zip bomb')),
      isTrue,
    );
  });

  test('拒绝：ZIP 条目数超过 10000 上限', () async {
    final path = '${tempRoot.path}/bomb_count.zip';
    final archive = Archive();
    final manifest = utf8.encode(validHtmlManifest());
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    for (var i = 0; i < 10001; i++) {
      final bytes = utf8.encode('x');
      archive.addFile(ArchiveFile('content/pad_$i.txt', bytes.length, bytes));
    }
    File(path).writeAsBytesSync(ZipEncoder().encode(archive)!);

    final result = await runImport(path);
    expect(result, isA<ImportFailure>());
    final failure = result as ImportFailure;
    expect(
      failure.issues.any((i) => i.code == IssueCode.zipInvalid && i.message.contains('条目数')),
      isTrue,
    );
  });

  // ---------- 单元级 ----------

  test('PathGuard：各种恶意/怪异路径', () {
    expect(PathGuard.sanitize('content/index.html'), 'content/index.html');
    expect(PathGuard.sanitize('..\\evil.txt'), isNull);
    expect(PathGuard.sanitize('/abs/path.txt'), isNull);
    expect(PathGuard.sanitize('C:/windows/system32.txt'), isNull);
    expect(PathGuard.sanitize('a/./b.txt'), 'a/b.txt');
    expect(PathGuard.sanitize('a//b//c.txt'), 'a/b/c.txt');
    expect(PathGuard.sanitize('a/../b.txt'), isNull);
    expect(PathGuard.sanitize('.hidden/.file'), '.hidden/.file');
  });

  test('TimedScheduleParser：跨午夜规则与解析错误', () {
    final (schedule, errors) = TimedScheduleParser.parse(timedSchedule());
    expect(errors, isEmpty);
    expect(schedule, isNotNull);

    // 09:00 → slot_day（06:00–18:00）
    expect(schedule!.resolveSlotName(9 * 60), 'slot_day');
    // 20:00 → slot_night（18:00–06:00 跨午夜）
    expect(schedule.resolveSlotName(20 * 60), 'slot_night');
    // 03:00 → slot_night（跨午夜的后半段）
    expect(schedule.resolveSlotName(3 * 60), 'slot_night');

    final (bad, badErrors) = TimedScheduleParser.parse(
      '{"rules":[{"from":"25:00","to":"x","wallpaper":""}]}',
    );
    expect(bad, isNull);
    expect(badErrors, isNotEmpty);
  });

  test('ManifestValidator.validateTimed：slot 内容为空被拒绝', () {
    final manifest = ManifestValidator.validateFields(
      Map<String, dynamic>.from(jsonDecode(timedManifest()) as Map),
      [],
    );
    expect(manifest, isNotNull);
    final info = ManifestValidator.validateTimed(
      manifest: manifest!,
      files: {
        'content/schedule.json',
        'content/slot_day/manifest.json',
        // slot_day 缺 content/
        'content/slot_night/manifest.json',
        'content/slot_night/content/color.jpg',
        'content/slot_night/content/depth.png',
      },
      scheduleBytes: utf8.encode(timedSchedule()),
      readFile: (_) => utf8.encode(slotManifest('com.test.timed.day')),
      issues: [],
    );
    expect(info, isNull);
  });
}
