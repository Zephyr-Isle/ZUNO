/// 壁纸库索引中的一条已安装记录。
///
/// 记录的是导入时校验过的稳定信息；文件本体位于应用私有目录
/// `<documents>/wallpapers/<id>/`（[packageDir]），删除条目时会一并删除。
class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.authorHandle,
    required this.type,
    required this.packageDir,
    required this.entry,
    this.thumbnailPath,
    required this.performanceHint,
    required this.configParams,
    required this.capabilities,
    required this.installedAt,
    required this.scheduleRules,
    required this.scheduleDefaultSlot,
    required this.slotIds,
  });

  final String id;
  final String version;
  final String title;
  final String? authorHandle;

  /// video | html | depth | timed
  final String type;

  /// 包根目录绝对路径（timed 包也指向其根目录；激活的 slot 目录运行时动态解析）。
  final String packageDir;

  /// 入口相对路径（如 content/main.mp4）。
  final String entry;
  final String? thumbnailPath;

  /// low | medium | high（来自 manifest.performanceHint）。
  final String performanceHint;

  /// manifest.config[] 原始列表（List<Map>），UI 据此渲染配置编辑器。
  final List<Map<String, dynamic>> configParams;

  /// manifest.capabilities 原始 map。
  final Map<String, dynamic> capabilities;
  final int installedAt;

  /// timed 专用：schedule.json 的 rules（List<Map>），供 UI 展示时间窗口。
  final List<Map<String, dynamic>> scheduleRules;
  final String scheduleDefaultSlot;

  /// timed 专用：slot 子包 id 列表。
  final List<String> slotIds;

  Map<String, dynamic> toMap() => {
    'id': id,
    'version': version,
    'title': title,
    'authorHandle': authorHandle,
    'type': type,
    'packageDir': packageDir,
    'entry': entry,
    'thumbnailPath': thumbnailPath,
    'performanceHint': performanceHint,
    'configParams': configParams,
    'capabilities': capabilities,
    'installedAt': installedAt,
    'scheduleRules': scheduleRules,
    'scheduleDefaultSlot': scheduleDefaultSlot,
    'slotIds': slotIds,
  };

  static LibraryEntry fromMap(Map<dynamic, dynamic> raw) => LibraryEntry(
    id: raw['id'] as String,
    version: raw['version'] as String,
    title: raw['title'] as String,
    authorHandle: raw['authorHandle'] as String?,
    type: raw['type'] as String,
    packageDir: raw['packageDir'] as String,
    entry: raw['entry'] as String,
    thumbnailPath: raw['thumbnailPath'] as String?,
    performanceHint: (raw['performanceHint'] as String?) ?? 'medium',
    configParams: (raw['configParams'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    capabilities: Map<String, dynamic>.from(
      raw['capabilities'] as Map? ?? const {},
    ),
    installedAt: (raw['installedAt'] as num?)?.toInt() ?? 0,
    scheduleRules: (raw['scheduleRules'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    scheduleDefaultSlot: (raw['scheduleDefaultSlot'] as String?) ?? '',
    slotIds: List<String>.from(raw['slotIds'] as List? ?? const []),
  );

  LibraryEntry copyWith({String? thumbnailPath}) => LibraryEntry(
    id: id,
    version: version,
    title: title,
    authorHandle: authorHandle,
    type: type,
    packageDir: packageDir,
    entry: entry,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    performanceHint: performanceHint,
    configParams: configParams,
    capabilities: capabilities,
    installedAt: installedAt,
    scheduleRules: scheduleRules,
    scheduleDefaultSlot: scheduleDefaultSlot,
    slotIds: slotIds,
  );
}
