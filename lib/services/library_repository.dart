import 'package:hive/hive.dart';

import 'package:zuno/models/library_entry.dart';

/// 壁纸库索引（规格要求 SQLite 或 Hive；这里用 Hive）。
///
/// 只存“已安装包的元数据”，文件本体在私有目录（见 ZunoPaths）。
/// Hive box 以 `id` 为 key，导入覆盖同 id 的记录（规格：相同 id 的包导入时覆盖）。
class LibraryRepository {
  LibraryRepository(this._box);

  static const boxName = 'zuno_library';

  final Box _box;

  static Future<LibraryRepository> open() async {
    try {
      final box = await Hive.openBox(boxName);
      return LibraryRepository(box);
    } catch (_) {
      // 索引文件损坏（异常断电/磁盘故障）不能让 App 永远无法启动：
      // 删除重建空库。损失的是索引元数据，壁纸包文件本体仍在私有目录，
      // 用户重新导入即可恢复（同 id 覆盖语义不受影响）。
      await Hive.deleteBoxFromDisk(boxName);
      final box = await Hive.openBox(boxName);
      return LibraryRepository(box);
    }
  }

  Future<void> put(LibraryEntry entry) => _box.put(entry.id, entry.toMap());

  Future<void> delete(String id) => _box.delete(id);

  LibraryEntry? get(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return LibraryEntry.fromMap(Map<dynamic, dynamic>.from(raw as Map));
  }

  List<LibraryEntry> getAll() {
    final result = <LibraryEntry>[];
    for (final raw in _box.values) {
      try {
        result.add(
          LibraryEntry.fromMap(Map<dynamic, dynamic>.from(raw as Map)),
        );
      } catch (_) {
        // 损坏的记录跳过，不阻塞其余条目。
      }
    }
    result.sort((a, b) => b.installedAt.compareTo(a.installedAt));
    return result;
  }
}
