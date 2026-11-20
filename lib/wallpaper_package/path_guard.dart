import 'dart:io';

/// ZIP 条目路径安全（防 Zip Slip / 路径遍历攻击）。
///
/// 规格要求：条目路径不得包含 `..` 或绝对路径。实践上还要防御：
/// - 反斜杠分隔（部分 Windows 打包工具生成），统一按分隔符归一化；
/// - 盘符绝对路径（`C:/...`）；
/// - 编码变体不做展开（ZIP 名单里是原始路径，无需处理 %2e）。
class PathGuard {
  PathGuard._();

  /// 把 ZIP 条目名归一化为安全的 POSIX 相对路径；不合法返回 null。
  static String? sanitize(String rawName) {
    var name = rawName.replaceAll('\\', '/');
    // 盘符（C:/）视为绝对路径。
    if (RegExp(r'^[A-Za-z]:').hasMatch(name)) return null;
    if (name.startsWith('/')) return null;
    final parts = <String>[];
    for (final seg in name.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') return null; // 一票否决
      if (seg.contains('\u0000')) return null;
      parts.add(seg);
    }
    if (parts.isEmpty) return null;
    return parts.join('/');
  }

  /// 双保险：磁盘上的规范化路径必须位于 [root] 内。
  static bool isInside(Directory root, FileSystemEntity target) {
    String rootPath;
    String targetPath;
    try {
      rootPath = root.resolveSymbolicLinksSync();
      targetPath = target.resolveSymbolicLinksSync();
    } on FileSystemException {
      return false;
    }
    // 分隔符按平台处理（Windows 为 '\'，POSIX 为 '/'）。
    final sep = Platform.pathSeparator;
    return targetPath == rootPath || targetPath.startsWith('$rootPath$sep');
  }
}
