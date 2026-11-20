import 'package:flutter_test/flutter_test.dart';

import 'package:zuno/models/remote_wallpaper.dart';

/// 云端契约测试：这些字段名是 `backend/src/wallpapers.ts` 与 `auth.ts`
/// 直接决定的，改名会让客户端静默丢数据（列表少字段 / 登录后没 token）。
/// 纯解析，不触达网络与 Platform Channel。
void main() {
  test('RemoteWallpaper：解析完整条目', () {
    final item = RemoteWallpaper.tryFromJson({
      'id': 'com.zuno.demo',
      'title': '示例壁纸',
      'author': 'tester',
      'type': 'video',
      'version': '1.0.0',
      'size': 1048576,
      'updatedAt': 1700000000000,
    });
    expect(item, isNotNull);
    expect(item!.id, 'com.zuno.demo');
    expect(item.author, 'tester');
    expect(item.type, 'video');
    // 1 MiB → 1.0 MB
    expect(item.sizeLabel, '1.0 MB');
  });

  test('RemoteWallpaper：author 缺失时回落 null，不影响整页', () {
    final item = RemoteWallpaper.tryFromJson({
      'id': 'a',
      'title': 'b',
      'type': 'html',
      'version': '1',
      'size': 0,
      'updatedAt': 0,
    });
    expect(item, isNotNull);
    expect(item!.author, isNull);
    // size 为 0（后端未拿到 Content-Length）不显示“0 B”。
    expect(item.sizeLabel, '大小未知');
    expect(item.updatedLabel, '');
  });

  test('RemoteWallpaper：缺必填字段返回 null 而不是抛异常', () {
    expect(RemoteWallpaper.tryFromJson(const {'id': 'a'}), isNull);
    expect(
      RemoteWallpaper.tryFromJson(const {
        'id': 'a',
        'title': 'b',
        'type': 'video',
        'version': 1, // 类型不对
      }),
      isNull,
    );
  });

  test('AuthSession：解析 token 与嵌套 user', () {
    final session = AuthSession.tryFromJson(const {
      'token': 'abc.def',
      'expiresAt': 4102444800000, // 2100-01-01
      'user': {'id': 'u1', 'email': 'a@b.co'},
    });
    expect(session, isNotNull);
    expect(session!.token, 'abc.def');
    expect(session.userId, 'u1');
    expect(session.email, 'a@b.co');
    expect(session.expired, isFalse);
  });

  test('AuthSession：空 token 视为失败', () {
    expect(AuthSession.tryFromJson(const {'token': ''}), isNull);
    expect(AuthSession.tryFromJson(const {}), isNull);
  });

  test('AuthSession：过期判定以 expiresAt 为准', () {
    final expired = AuthSession.tryFromJson(const {
      'token': 't',
      'expiresAt': 1,
      'user': {'id': 'u', 'email': 'a@b.co'},
    });
    expect(expired!.expired, isTrue);
  });

  test('DownloadTicket：url 是相对路径，原样保留', () {
    final ticket = DownloadTicket.tryFromJson(const {
      'ticket': 'x.y',
      'url': '/download/com.demo?ticket=x.y',
      'expiresAt': 4102444800000,
      'size': 2048,
    });
    expect(ticket, isNotNull);
    expect(ticket!.url.startsWith('/download/'), isTrue);
    expect(ticket.size, 2048);
  });

  test('formatBytes：1024 进制与单位选择', () {
    expect(formatBytes(0), '大小未知');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(20 * 1024 * 1024), '20.0 MB');
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
  });
}
