import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// manifest.checksum 的规范计算（ZUNO Package v1）。
///
/// 规范（README 有完整说明）：
/// 1. 取 `content/` 下所有普通文件（递归）；
/// 2. 按其相对包根的 POSIX 路径做码元（code unit）升序排序；
/// 3. 依次把 `相对路径的 UTF-8 字节` + `0x0A` + `文件字节` 追加进同一个 SHA-256 状态；
/// 4. 结果表示为 `sha256-<小写 hex>`。
class PackageChecksum {
  PackageChecksum._();

  static const scheme = 'sha256-';

  static Future<String> compute(Directory packageRoot) async {
    final contentDir = Directory(
      '${packageRoot.path}${Platform.pathSeparator}content',
    );
    if (!contentDir.existsSync()) {
      throw const FileSystemException('content/ missing');
    }
    final files = <File, String>{};
    await for (final entity in contentDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final rel = entity.path
            .substring(packageRoot.path.length)
            .replaceAll(Platform.pathSeparator, '/')
            .replaceFirst(RegExp(r'^/+'), '');
        files[entity] = rel;
      }
    }
    final ordered = files.keys.toList()
      ..sort((a, b) => files[a]!.compareTo(files[b]!));
    final output = _DigestSink();
    final input = sha256.startChunkedConversion(output);
    for (final f in ordered) {
      input.add(utf8.encode(files[f]!));
      input.add([0x0A]);
      // 流式读取：之前用 readAsBytes() 把整个文件读进内存，大视频包导入时
      // isolate 峰值内存 = 最大单文件，前面的 ZIP 流式解压就白做了。
      // openRead 按 64KB 块喂入哈希，内存恒定。
      await for (final chunk in f.openRead()) {
        input.add(chunk);
      }
    }
    input.close();
    return scheme + output.digest!.toString();
  }

  static bool verify(String expected, String actual) {
    final e = _stripScheme(expected.trim().toLowerCase());
    final a = _stripScheme(actual.trim().toLowerCase());
    return e == a;
  }

  /// 兼容带/不带 `sha256-` 前缀的两种写法。
  static String _stripScheme(String hex) =>
      hex.startsWith(scheme) ? hex.substring(scheme.length) : hex;
}

/// 流式哈希的终结 sink（避免为 AccumulatorSink 引入 package:convert 依赖）。
class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
