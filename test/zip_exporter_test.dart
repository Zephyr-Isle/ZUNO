import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';
import 'package:zuno/wallpaper_package/zip_exporter.dart';
import 'package:zuno/wallpaper_package/zip_importer.dart';

/// 导出 ↔ 导入 round-trip 测试：
/// 导出的 .zuno 必须能通过完整导入校验（manifest/checksum/结构全部成立），
/// 且元数据与原条目一致。这验证了 zip_exporter 与 checksum 规范的双侧一致性。
void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zuno_export_test_');
  });

  tearDown(() async {
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('导出 → 再导入：校验通过、元数据一致、checksum 成立', () async {
    // ---------- 1. 先导入一个合法包 ----------
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'id': 'com.test.roundtrip',
      'version': '2.1.0',
      'title': 'Round Trip',
      'author': {'handle': 'tester'},
      'type': 'html',
      'entry': 'content/index.html',
      'minSdk': 24,
      'capabilities': {'network': [], 'pointer': true, 'sensors': []},
    });
    final sourceZip = File('${tempRoot.path}/source.zip');
    final archive = Archive()
      ..addFile(
        ArchiveFile('manifest.json', manifest.length, utf8.encode(manifest)),
      )
      ..addFile(
        ArchiveFile(
          'content/index.html',
          24,
          utf8.encode('<html><body>rt</body></html>'),
        ),
      )
      ..addFile(
        ArchiveFile('content/assets/app.js', 10, utf8.encode('// app')),
      );
    sourceZip.writeAsBytesSync(ZipEncoder().encode(archive)!);

    final import1 = await importZunoPackage(
      zipPath: sourceZip.path,
      stagingParentPath: tempRoot.path,
      libraryRootPath: '${tempRoot.path}/library',
      deviceApiLevel: 34,
    );
    expect(import1, isA<ImportOutcome>());
    final first = import1 as ImportOutcome;

    // ---------- 2. 导出 ----------
    final exportedPath =
        '${tempRoot.path}/exports/com_test_roundtrip_2.1.0.zuno';
    final ok = await exportPackageToZip(
      packageDir: first.entry.packageDir,
      outPath: exportedPath,
    );
    expect(ok, isTrue);
    expect(File(exportedPath).existsSync(), isTrue);
    expect(File(exportedPath).lengthSync(), greaterThan(0));

    // ---------- 3. 重新导入导出的包 ----------
    final import2 = await importZunoPackage(
      zipPath: exportedPath,
      stagingParentPath: tempRoot.path,
      libraryRootPath: '${tempRoot.path}/library2',
      deviceApiLevel: 34,
    );
    expect(
      import2,
      isA<ImportOutcome>(),
      reason:
          '导出的包必须能通过完整导入校验（含 checksum）：'
          '${import2 is ImportFailure ? import2.issues.join('; ') : ''}',
    );
    final second = import2 as ImportOutcome;

    // ---------- 4. 元数据一致性 ----------
    expect(second.manifest.id, first.manifest.id);
    expect(second.manifest.version, first.manifest.version);
    expect(second.manifest.checksum, first.manifest.checksum);
    expect(second.entry.title, first.entry.title);
    expect(second.entry.authorHandle, 'tester');
    expect(second.entry.capabilities['pointer'], true);
  });

  test('导出失败路径：包目录不存在返回 false', () async {
    final ok = await exportPackageToZip(
      packageDir: '${tempRoot.path}/no_such_dir',
      outPath: '${tempRoot.path}/out.zuno',
    );
    expect(ok, isFalse);
    expect(File('${tempRoot.path}/out.zuno').existsSync(), isFalse);
  });

  test('拒绝导入类型检查与导出无关（防御性冒烟）', () async {
    // 直接调用导出一个"包目录缺 manifest"的目录：导出器不做语义校验
    // （它信任库内数据），只做字节打包——此测试锁定该行为。
    final dir = Directory('${tempRoot.path}/pkg')..createSync();
    File('${dir.path}/content/index.html')
      ..createSync(recursive: true)
      ..writeAsStringSync('<html></html>');
    final ok = await exportPackageToZip(
      packageDir: dir.path,
      outPath: '${tempRoot.path}/raw.zuno',
    );
    expect(ok, isTrue);
    expect(File('${tempRoot.path}/raw.zuno').existsSync(), isTrue);
  });
}
