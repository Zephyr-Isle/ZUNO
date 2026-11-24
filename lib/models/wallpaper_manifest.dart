import 'package:zuno/l10n/zuno_strings.dart';
import 'package:zuno/models/wallpaper_type.dart';

/// manifest.json 解析模型（ZUNO Package v1）。
///
/// 解析是“严格失败”的：任何字段类型不符都会抛出 [ManifestFormatException]，
/// 由导入流程捕获并转为用户可读的校验失败原因。
class ManifestFormatException implements Exception {
  ManifestFormatException(this.field, this.reason);

  final String field;
  final String reason;

  @override
  String toString() => 'manifest.$field: $reason';
}

class WallpaperAuthor {
  const WallpaperAuthor({this.id, this.handle});

  final String? id;
  final String? handle;

  static WallpaperAuthor? parse(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw ManifestFormatException(
        'author',
        ZunoStrings.current.reasonMustBeObject,
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return WallpaperAuthor(
      id: _optString(map, 'id'),
      handle: _optString(map, 'handle'),
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'handle': handle};
}

/// 用户可调参数定义（manifest.config[]）。
class ConfigParam {
  const ConfigParam({
    required this.key,
    required this.type,
    this.label,
    this.min,
    this.max,
    required this.defaultValue,
    this.note,
  });

  final String key;

  /// float | int | bool | color
  final String type;
  final String? label;
  final num? min;
  final num? max;
  final Object? defaultValue;
  final String? note;

  static ConfigParam parse(Object? raw, int index) {
    if (raw is! Map) {
      throw ManifestFormatException(
        'config[$index]',
        ZunoStrings.current.reasonConfigObject(index),
      );
    }
    final map = Map<String, dynamic>.from(raw);
    final key = map['key'];
    if (key is! String || key.isEmpty) {
      throw ManifestFormatException(
        'config[$index].key',
        ZunoStrings.current.reasonConfigKey(index),
      );
    }
    final type = map['type'];
    if (type is! String ||
        !const {'float', 'int', 'bool', 'color'}.contains(type)) {
      throw ManifestFormatException(
        'config[$index].type',
        ZunoStrings.current.reasonConfigType(index, type),
      );
    }
    final dynamic def = map['default'];
    // default 类型必须与 type 匹配（color 为 "#RRGGBB" 字符串）。
    switch (type) {
      case 'float':
        if (def != null && def is! num) {
          throw ManifestFormatException(
            'config[$index].default',
            ZunoStrings.current.reasonDefaultFloat,
          );
        }
      case 'int':
        if (def != null && (def is! num || def.toInt() != def)) {
          throw ManifestFormatException(
            'config[$index].default',
            ZunoStrings.current.reasonDefaultInt,
          );
        }
      case 'bool':
        if (def != null && def is! bool) {
          throw ManifestFormatException(
            'config[$index].default',
            ZunoStrings.current.reasonDefaultBool,
          );
        }
      case 'color':
        if (def != null &&
            (def is! String || !RegExp(r'^#[0-9a-fA-F]{6,8}$').hasMatch(def))) {
          throw ManifestFormatException(
            'config[$index].default',
            ZunoStrings.current.reasonDefaultColor,
          );
        }
    }
    final min = _optNum(map, 'min');
    final max = _optNum(map, 'max');
    if (min != null && max != null && min > max) {
      throw ManifestFormatException(
        'config[$index]',
        ZunoStrings.current.reasonMinMax,
      );
    }
    return ConfigParam(
      key: key,
      type: type,
      label: _optString(map, 'label'),
      min: min,
      max: max,
      defaultValue: def,
      note: _optString(map, 'note'),
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'type': type,
    if (label != null) 'label': label,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (defaultValue != null) 'default': defaultValue,
    if (note != null) 'note': note,
  };
}

/// 能力声明（manifest.capabilities）。
class Capabilities {
  const Capabilities({
    this.network = const [],
    this.pointer = false,
    this.sensors = const [],
  });

  final List<String> network;
  final bool pointer;
  final List<String> sensors;

  static Capabilities parse(Object? raw) {
    if (raw == null) return const Capabilities();
    if (raw is! Map) {
      throw ManifestFormatException(
        'capabilities',
        ZunoStrings.current.reasonCapabilitiesObject,
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return Capabilities(
      network: _stringList(map['network'], 'capabilities.network'),
      pointer: map['pointer'] == true,
      sensors: _stringList(map['sensors'], 'capabilities.sensors'),
    );
  }

  /// 严格校验的字符串数组解析：元素类型不符必须抛 [ManifestFormatException]
  /// （而不是让 `List<String>.from` 抛 TypeError 逃过校验层导致导入崩溃）。
  static List<String> _stringList(Object? raw, String field) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw ManifestFormatException(
        field,
        ZunoStrings.current.reasonStringArray,
      );
    }
    for (final e in raw) {
      if (e is! String) {
        throw ManifestFormatException(
          field,
          ZunoStrings.current.reasonElementString(e),
        );
      }
    }
    return List<String>.from(raw);
  }

  Map<String, dynamic> toMap() => {
    'network': network,
    'pointer': pointer,
    'sensors': sensors,
  };
}

class WallpaperManifest {
  const WallpaperManifest({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.title,
    this.author,
    required this.type,
    required this.entry,
    required this.minSdk,
    this.checksum,
    required this.performanceHint,
    required this.config,
    required this.capabilities,
  });

  final int schemaVersion;
  final String id;
  final String version;
  final String title;
  final WallpaperAuthor? author;
  final WallpaperType type;
  final String entry;
  final int minSdk;
  final String? checksum;

  /// low | medium | high（用于初始性能档位建议）。
  final String performanceHint;
  final List<ConfigParam> config;
  final Capabilities capabilities;

  static WallpaperManifest parse(Map<String, dynamic> raw) {
    final schemaVersion = _reqInt(raw, 'schemaVersion');
    if (schemaVersion != 1) {
      throw ManifestFormatException(
        'schemaVersion',
        ZunoStrings.current.reasonSchemaOnly1(schemaVersion),
      );
    }
    final id = _reqString(raw, 'id');
    // 字符集白名单之外，显式拒绝 "." 与 ".."：id 会拼进包目录路径
    // （libraryRoot/<id>），放行它们等于给 ZIP 包一个目录遍历原语。
    if (!RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(id) || id == '.' || id == '..') {
      throw ManifestFormatException(
        'id',
        ZunoStrings.current.reasonIdCharset(id),
      );
    }
    final version = _reqString(raw, 'version');
    // 语义化版本（宽松校验：三段数字）。
    if (!RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$').hasMatch(version)) {
      throw ManifestFormatException(
        'version',
        ZunoStrings.current.reasonSemver(version),
      );
    }
    final type = WallpaperType.tryParse(_reqString(raw, 'type'));
    if (type == null) {
      throw ManifestFormatException(
        'type',
        ZunoStrings.current.reasonTypeOneOf,
      );
    }
    final minSdk = _optInt(raw, 'minSdk') ?? 24;
    final hint = _optString(raw, 'performanceHint') ?? 'medium';
    if (!const {'low', 'medium', 'high'}.contains(hint)) {
      throw ManifestFormatException(
        'performanceHint',
        ZunoStrings.current.reasonPerformanceHint(hint),
      );
    }
    final configRaw = raw['config'];
    if (configRaw != null && configRaw is! List) {
      throw ManifestFormatException(
        'config',
        ZunoStrings.current.reasonConfigArray,
      );
    }
    final configList = (configRaw as List? ?? const [])
        .asMap()
        .map((i, e) => MapEntry(i, ConfigParam.parse(e, i)))
        .values
        .toList();
    // config key 去重。
    final keys = configList.map((c) => c.key).toSet();
    if (keys.length != configList.length) {
      throw ManifestFormatException(
        'config',
        ZunoStrings.current.reasonDuplicateKeys,
      );
    }
    return WallpaperManifest(
      schemaVersion: schemaVersion,
      id: id,
      version: version,
      title: _reqString(raw, 'title'),
      author: WallpaperAuthor.parse(raw['author']),
      type: type,
      entry: _reqString(raw, 'entry'),
      minSdk: minSdk,
      checksum: _optString(raw, 'checksum'),
      performanceHint: hint,
      config: configList,
      capabilities: Capabilities.parse(raw['capabilities']),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'title': title,
    if (author != null) 'author': author!.toMap(),
    'type': type.wire,
    'entry': entry,
    'minSdk': minSdk,
    if (checksum != null) 'checksum': checksum,
    'performanceHint': performanceHint,
    'config': config.map((c) => c.toMap()).toList(),
    'capabilities': capabilities.toMap(),
  };
}

// ---------- 严格解析辅助 ----------

String _reqString(Map<String, dynamic> raw, String field) {
  final v = raw[field];
  if (v is! String || v.isEmpty) {
    throw ManifestFormatException(
      field,
      ZunoStrings.current.reasonRequiredString(v),
    );
  }
  return v;
}

String? _optString(Map<String, dynamic> raw, String field) {
  final v = raw[field];
  if (v == null) return null;
  if (v is! String) {
    throw ManifestFormatException(
      field,
      ZunoStrings.current.reasonMustBeString(v),
    );
  }
  return v;
}

int _reqInt(Map<String, dynamic> raw, String field) {
  final v = raw[field];
  if (v is! num || v.toInt() != v) {
    throw ManifestFormatException(
      field,
      ZunoStrings.current.reasonRequiredInt(v),
    );
  }
  return v.toInt();
}

int? _optInt(Map<String, dynamic> raw, String field) {
  final v = raw[field];
  if (v == null) return null;
  if (v is! num || v.toInt() != v) {
    throw ManifestFormatException(
      field,
      ZunoStrings.current.reasonMustBeInt(v),
    );
  }
  return v.toInt();
}

num? _optNum(Map<String, dynamic> raw, String field) {
  final v = raw[field];
  if (v == null) return null;
  if (v is! num) {
    throw ManifestFormatException(
      field,
      ZunoStrings.current.reasonMustBeNumber(v),
    );
  }
  return v;
}
