// 通用 .zuno 打包器。
//
// 把一个 staging 目录里的若干"包目录"分别打包成 .zuno（ZUNO Package v1）。
// 每个包目录结构：
//   <包目录>/
//   ├── manifest.json     # 必需，可不含 checksum 字段（工具按规范重算后写回）
//   ├── thumbnail.png     # 可选
//   └── content/          # 必需，所有壁纸素材
//
// 用法（在项目根目录）：
//   dart run tool/pack_zuno.dart --src <staging 目录> --out <输出目录>
//
// checksum 算法与 lib/wallpaper_package/checksum.dart、tool/create_sample_packages.dart
// 三侧一致：content/ 下所有文件按相对包根的 POSIX 路径码元升序排序，
// 依次把 `路径 UTF-8 字节 + 0x0A + 文件字节` 追加进同一 SHA-256 状态，
// 结果表示为 `sha256-<小写 hex>`。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;

void main(List<String> args) {
  final src = _argValue(args, '--src');
  final out = _argValue(args, '--out') ?? 'build/zuno';
  if (src == null) {
    stderr.writeln('用法：dart run tool/pack_zuno.dart --src <staging 目录> [--out <输出目录>]');
    exitCode = 2;
    return;
  }
  final srcDir = Directory(src);
  if (!srcDir.existsSync()) {
    stderr.writeln('错误：--src 目录不存在: $src');
    exitCode = 2;
    return;
  }

  final outDir = Directory(out);
  outDir.createSync(recursive: true);

  // 每个含 manifest.json 的子目录 = 一个包。
  final packages = srcDir.listSync().whereType<Directory>().where((d) {
    return File('${d.path}/manifest.json').existsSync();
  }).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  if (packages.isEmpty) {
    stderr.writeln('错误：--src 下没有任何含 manifest.json 的子目录');
    exitCode = 2;
    return;
  }

  for (final pkg in packages) {
    _packPackage(pkg, outDir);
  }
  stdout.writeln('\n完成。共打包 ${packages.length} 个包到 ${outDir.path}/');
}

String? _argValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) return args[i + 1];
  }
  return null;
}

void _packPackage(Directory pkgDir, Directory outDir) {
  final name = pkgDir.path.split(Platform.pathSeparator).last;

  // ---------- 收集包内文件（manifest.json + thumbnail.png + content/**） ----------
  final files = <String, List<int>>{};

  final manifestFile = File('${pkgDir.path}/manifest.json');
  files['manifest.json'] = manifestFile.readAsBytesSync();

  final thumbnail = File('${pkgDir.path}/thumbnail.png');
  if (thumbnail.existsSync()) files['thumbnail.png'] = thumbnail.readAsBytesSync();

  final contentDir = Directory('${pkgDir.path}/content');
  if (!contentDir.existsSync()) {
    stderr.writeln('错误：$name 缺少 content/ 目录');
    exitCode = 2;
    return;
  }
  for (final entity in contentDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = entity.path
        .substring(pkgDir.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    files[rel] = entity.readAsBytesSync();
  }

  // ---------- 重算 checksum 并写回 manifest ----------
  files['manifest.json'] = _withChecksum(files);

  // ---------- 写 zip（排序写入，保证产物可复现） ----------
  final archive = Archive();
  final names = files.keys.toList()..sort();
  for (final name2 in names) {
    final data = files[name2]!;
    // 大体积二进制用 STORE：视频等本身已压缩，deflate 纯浪费。
    if (data.length > 8 * 1024 * 1024) {
      archive.addFile(ArchiveFile.noCompress(name2, data.length, data));
    } else {
      archive.addFile(ArchiveFile(name2, data.length, data));
    }
  }
  final zipBytes = ZipEncoder().encode(archive)!;
  final outPath = '${outDir.path}/$name.zuno';
  File(outPath).writeAsBytesSync(zipBytes);

  final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, dynamic>;
  stdout.writeln(
    '✓ $name.zuno  id=${manifest['id']}  type=${manifest['type']}  '
    'files=${names.length - 1}  ${(zipBytes.length / 1024).toStringAsFixed(0)} KB\n'
    '  checksum=${manifest['checksum']}',
  );
}

/// 按 README 规定的规范计算 checksum 并写回 manifest：
/// 对 content/ 下所有文件按相对路径排序后，依次累加 `路径 UTF-8 字节 + 0x0A + 文件字节`。
List<int> _withChecksum(Map<String, List<int>> files) {
  final relPaths = files.keys
      .where((p) => p != 'manifest.json' && p != 'thumbnail.png' && p.startsWith('content/'))
      .toList()
    ..sort((a, b) => a.compareTo(b));
  final payload = BytesBuilder();
  for (final p in relPaths) {
    payload.add(utf8.encode(p));
    payload.add([0x0A]);
    payload.add(files[p]!);
  }
  final hex = crypto.sha256.convert(payload.toBytes()).toString();
  final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, dynamic>;
  manifest['checksum'] = 'sha256-$hex';
  return utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
}
