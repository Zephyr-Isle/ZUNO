import 'package:zuno/l10n/zuno_strings.dart';

// 云端壁纸目录的数据模型（对应 zuno-api 的 JSON 契约）。
//
// 后端不下发 `webdav_path` / `cover_path`（见 internal-docs/docs/backend.md）：客户端只拿
// id、元数据与 `hasCover` 布尔值；封面图通过 `/api/wallpapers/:id/cover`
// 代理获取（下载前即可在壁纸库列表预览），真正的包仍走一次性票据下载。

/// 目录中的一条壁纸记录（`GET /api/wallpapers` 的 items 元素）。
class RemoteWallpaper {
  const RemoteWallpaper({
    required this.id,
    required this.title,
    required this.type,
    required this.version,
    required this.size,
    required this.updatedAt,
    this.author,
    this.hasCover = false,
  });

  final String id;
  final String title;

  /// video | html | depth | timed
  final String type;
  final String version;

  /// 包文件字节数。
  final int size;

  /// 后端写入的更新时间（epoch millis）。
  final int updatedAt;
  final String? author;

  /// 服务端是否有封面图；为 true 时列表用 `/api/wallpapers/:id/cover` 预览。
  final bool hasCover;

  static RemoteWallpaper? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final type = json['type'];
    final version = json['version'];
    if (id is! String || title is! String || type is! String || version is! String) {
      return null;
    }
    return RemoteWallpaper(
      id: id,
      title: title,
      type: type,
      version: version,
      size: (json['size'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      author: json['author'] as String?,
      hasCover: json['hasCover'] == true,
    );
  }

  String get sizeLabel => formatBytes(size);

  /// 更新时间（本地时区，精确到分钟）。
  String get updatedLabel {
    if (updatedAt <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// 一页目录数据。`nextCursor == null` 表示已经到底。
class CatalogPage {
  const CatalogPage({required this.items, this.nextCursor});

  final List<RemoteWallpaper> items;
  final String? nextCursor;
}

/// 登录/注册成功后的会话。
class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.expiresAt,
  });

  /// Bearer token（服务端只存它的 SHA-256，原始值仅此一份）。
  final String token;
  final String userId;
  final String email;

  /// 过期时间（epoch millis）。
  final int expiresAt;

  bool get expired => DateTime.now().millisecondsSinceEpoch >= expiresAt;

  static AuthSession? tryFromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) return null;
    final user = json['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : const <String, dynamic>{};
    return AuthSession(
      token: token,
      userId: userMap['id'] as String? ?? '',
      email: userMap['email'] as String? ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 一次性下载票据（5 分钟有效，只对指定壁纸有效）。
class DownloadTicket {
  const DownloadTicket({
    required this.ticket,
    required this.url,
    required this.expiresAt,
    required this.size,
  });

  final String ticket;

  /// 相对路径，如 `/download/<id>?ticket=...`；客户端自行拼 baseUrl。
  final String url;
  final int expiresAt;
  final int size;

  static DownloadTicket? tryFromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final ticket = json['ticket'];
    if (url is! String || ticket is! String) return null;
    return DownloadTicket(
      ticket: ticket,
      url: url,
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 人类可读的字节数。壁纸包从几十 KB（HTML）到几十 MB（视频）都有。
String formatBytes(int bytes) {
  if (bytes <= 0) return ZunoStrings.current.errSizeUnknown;
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final text = unit == 0 || value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
