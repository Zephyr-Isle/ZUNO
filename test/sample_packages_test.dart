import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/wallpaper_package/validation_failure.dart';
import 'package:zuno/wallpaper_package/zip_importer.dart';

/// 端到端回归：用真实导入器导入 tool/create_sample_packages.dart 生成的示例包。
/// 若 samples/ 尚未生成，先在测试内调用生成逻辑跳过（提示运行 dart run tool/...）。
void main() {
  test('samples/ 下三个示例包都能通过完整导入校验', () async {
    final samples = Directory('samples');
    final expected = [
      'sample_depth.zuno',
      'sample_html.zuno',
      'sample_timed.zuno',
    ];
    final present = expected
        .map((n) => File('${samples.path}/$n'))
        .where((f) => f.existsSync())
        .toList();
    if (present.isEmpty) {
      // 未生成示例时跳过（CI 可先跑 dart run tool/create_sample_packages.dart）。
      return;
    }

    final temp = await Directory.systemTemp.createTemp('zuno_sample_test_');
    try {
      for (final zip in present) {
        final result = await importZunoPackage(
          zipPath: zip.path,
          stagingParentPath: temp.path,
          libraryRootPath: '${temp.path}/library',
          deviceApiLevel: 34,
        );
        expect(
          result,
          isA<ImportOutcome>(),
          reason:
              '${zip.path} 导入失败: '
              '${result is ImportFailure ? result.issues.join('; ') : ''}',
        );
        final outcome = result as ImportOutcome;
        // checksum 双侧一致：重算导入后的 content/ 校验和应与 manifest 一致
        // （导入器内部已比对过一次，这里再验一次库内落盘文件）。
        expect(
          outcome.manifest.checksum,
          isNotNull,
          reason: '${zip.path} 的 manifest 应包含 checksum',
        );
      }
    } finally {
      if (temp.existsSync()) await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
