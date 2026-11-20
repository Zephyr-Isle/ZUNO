import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:zuno/wallpaper_package/path_guard.dart';

/// 把已安装的壁纸包目录打包为 .zuno（ZIP）文件。
///
/// 与导入器对称的流式实现：`ArchiveFile.stream` 持有文件句柄、
/// `ZipEncoder.startEncode/addFile/endEncode` 逐条目写入 `OutputFileStream`，
/// 峰值内存 = 编码缓冲（几十 KB），大视频包也不会整包进内存。
///
/// 包文件自导入后不会被 ZUNO 改动（用户参数存于 SharedPreferences），
/// manifest 里的 checksum 对导出的字节依然成立——导出的包可直接再导入。
///
/// 导入与导出的条目名都经过 [PathGuard] 归一化：磁盘上的文件名来自导入时
/// 的安全名单，这里再做一次校验属于双保险（防目录被外部工具改动）。
Future<bool> exportPackageToZip({
  required String packageDir,
  required String outPath,
}) async {
  OutputFileStream? output;
  try {
    final root = Directory(packageDir);
    if (!root.existsSync()) return false;

    final files =
        root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList()
          ..sort((a, b) {
            final ra = _rel(root, a);
            final rb = _rel(root, b);
            return ra.compareTo(rb);
          });
    if (files.isEmpty) return false;

    output = OutputFileStream(outPath);
    final encoder = ZipEncoder();
    encoder.startEncode(output);
    // 收集每个条目的输入流：正常路径 endEncode 会收尾，异常路径（编码中途
    // 抛错）也必须关闭——Windows 上未关闭句柄会锁住包文件，删除/重导都失败。
    final openInputs = <InputFileStream>[];
    try {
      for (final f in files) {
        final rel = _rel(root, f);
        if (PathGuard.sanitize(rel) == null) {
          // 磁盘上出现了可疑文件名（外部改动）：跳过该文件，不让它进包。
          continue;
        }
        final input = InputFileStream(f.path);
        openInputs.add(input);
        final entry = ArchiveFile.stream(rel, f.lengthSync(), input);
        encoder.addFile(entry);
      }
      encoder.endEncode();
      return true;
    } finally {
      for (final s in openInputs) {
        try {
          s.closeSync();
        } catch (_) {}
      }
    }
  } catch (_) {
    // 失败时清掉半成品，避免残留一个不可用的 .zuno 被分享出去。
    try {
      final f = File(outPath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    return false;
  } finally {
    // endEncode 正常收尾后 OutputFileStream 已关闭；此处兜底关闭
    // （中途异常时输出流还开着），重复关闭用 runCatching 吞掉。
    if (output != null) {
      try {
        output.closeSync();
      } catch (_) {}
    }
  }
}

String _rel(Directory root, File f) => f.path
    .substring(root.path.length)
    .replaceAll('\\', '/')
    .replaceFirst(RegExp(r'^/+'), '');
