import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// ZUNO 的目录约定（与 README 一致）。
///
/// - 壁纸库：`<documents>/wallpapers/<id>/`（manifest.json + thumbnail.png + content/）
/// - 导入暂存：`<support>/import_tmp/<uuid>/`（校验通过后原子 rename 进壁纸库）
class ZunoPaths {
  ZunoPaths._();

  static Directory? _libraryRoot;
  static Directory? _stagingRoot;

  /// `<documents>/wallpapers`
  static Future<Directory> libraryRoot() async {
    final cached = _libraryRoot;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}wallpapers');
    await dir.create(recursive: true);
    _libraryRoot = dir;
    return dir;
  }

  /// `<support>/import_tmp`
  static Future<Directory> stagingRoot() async {
    final cached = _stagingRoot;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}import_tmp');
    await dir.create(recursive: true);
    _stagingRoot = dir;
    return dir;
  }
}
