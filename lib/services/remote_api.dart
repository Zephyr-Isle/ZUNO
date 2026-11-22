import 'dart:convert';
import 'dart:io';

import 'package:zuno/models/remote_wallpaper.dart';

/// 服务端返回的可展示错误。
///
/// `statusCode == 0` 表示压根没连上（DNS/网络/证书），此时 [message] 是
/// 面向用户的说明；其余情况来自后端统一错误体 `{error, message}`。
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// zuno-api 客户端。
///
/// 刻意不引入 `http` 包：后端只有 5 个 JSON 端点加一次流式下载，
/// `dart:io` 的 HttpClient 全覆盖，且能直接消费字节流做进度回调，
/// 少一个依赖就少一处版本冲突。
class RemoteApi {
  /// [baseUrl] 默认为空（未配置）：壁纸库页会显示引导去设置的空态，
  /// 不会用空地址发请求。配置来自用户自己部署的 zuno-api。
  RemoteApi({String baseUrl = ''}) : baseUrl = _normalize(baseUrl);

  /// 末尾不带斜杠。可在运行时通过 [updateBaseUrl] 指向自建后端。
  String baseUrl;

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');

  /// 切换后端地址（设置页保存/清除后调用；空字符串 = 未配置）。
  ///
  /// 同时关掉旧连接池：HttpClient 会按 host 复用连接，换域名后继续用旧池
  /// 只会拿到一堆失效 socket。
  void updateBaseUrl(String value) {
    final next = _normalize(value);
    if (next == baseUrl) return;
    baseUrl = next;
    _client?.close(force: true);
    _client = null;
  }

  HttpClient? _client;

  HttpClient get _http => _client ??= HttpClient()
    // 移动网络握手慢，5 秒太紧；连接阶段超时与整体超时分开设置。
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  // ---------------------------------------------------------------- 账号

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final json = await _send(
      'POST',
      '/api/auth/register',
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.tryFromJson(json);
    if (session == null) {
      throw ApiException(200, 'bad_response', '服务器返回的会话数据不完整');
    }
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.tryFromJson(json);
    if (session == null) {
      throw ApiException(200, 'bad_response', '服务器返回的会话数据不完整');
    }
    return session;
  }

  /// 注销：服务端只删这一条 session，失败也不影响本地登出。
  Future<void> logout(String token) =>
      _send('POST', '/api/auth/logout', token: token);

  // ---------------------------------------------------------------- 目录

  Future<CatalogPage> listWallpapers({String? cursor, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null && cursor.isNotEmpty) query['cursor'] = cursor;
    final uri = Uri(path: '/api/wallpapers', queryParameters: query);
    final json = await _send('GET', uri.toString());

    final rawItems = json['items'];
    final items = <RemoteWallpaper>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          final item = RemoteWallpaper.tryFromJson(
            Map<String, dynamic>.from(raw),
          );
          // 单条脏数据不该让整页失败。
          if (item != null) items.add(item);
        }
      }
    }
    return CatalogPage(items: items, nextCursor: json['nextCursor'] as String?);
  }

  // ---------------------------------------------------------------- 下载

  /// 换取一次性下载票据。
  ///
  /// 登录是可选的：不带 token 时服务端记 `uid=anon` 并照常签发，
  /// 所以壁纸库不登录也能下载。token 失效（401/403）时调用方可以直接重试
  /// 一次匿名请求，本方法不自动降级，避免掩盖账号问题。
  Future<DownloadTicket> requestTicket({
    required String wallpaperId,
    String? token,
  }) async {
    final json = await _send(
      'POST',
      '/api/wallpapers/${Uri.encodeComponent(wallpaperId)}/ticket',
      token: token,
    );
    final ticket = DownloadTicket.tryFromJson(json);
    if (ticket == null) {
      throw ApiException(200, 'bad_response', '服务器返回的下载票据不完整');
    }
    return ticket;
  }

  /// 流式下载到 [target]。
  ///
  /// 必须流式：视频壁纸包动辄几十 MB，`readAsBytes` 会在低内存设备上直接 OOM。
  /// 服务端支持 Range，这里不传 range（整包下载最省事），但 206 也接受。
  Future<void> downloadToFile(
    String pathOrUrl,
    File target, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final uri = Uri.parse(
      pathOrUrl.startsWith('http') ? pathOrUrl : '$baseUrl$pathOrUrl',
    );
    HttpClientRequest request;
    try {
      request = await _http.getUrl(uri);
    } catch (error) {
      throw ApiException(0, 'network', '无法连接服务器：$error');
    }
    final response = await request.close();
    if (response.statusCode != 200 && response.statusCode != 206) {
      final body = await response.transform(utf8.decoder).join();
      throw ApiException(
        response.statusCode,
        'download_failed',
        '下载失败（HTTP ${response.statusCode}）'
            '${body.isEmpty ? '' : '：$body'}',
      );
    }
    final total = response.contentLength > 0 ? response.contentLength : null;
    final sink = target.openWrite();
    var received = 0;
    try {
      // stall 超时：连接超时只管握手，服务端 accept 后停流会让下载永远卡住。
      // 流上 60s 收不到任何新 chunk 即判定挂死，抛出后由调用方删半截文件。
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      // 出错时也关闭 sink，调用方负责删掉半截文件。
      await sink.close();
    }
  }

  // ---------------------------------------------------------------- 内部

  /// 发一次请求并解析 JSON。非 2xx 一律转 [ApiException]。
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    HttpClientRequest request;
    try {
      request = await _http.openUrl(method, uri);
    } catch (error) {
      throw ApiException(0, 'network', '无法连接服务器：$error');
    }
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      request.contentLength = bytes.length;
      request.add(bytes);
    }

    HttpClientResponse response;
    try {
      // 连接超时（15s）只管握手；这里再给「发请求 → 收到响应头」一个整体
      // 超时，服务端 accept 后挂死不回包时目录页才不会永远转圈。
      response = await request.close().timeout(const Duration(seconds: 30));
    } catch (error) {
      throw ApiException(0, 'network', '请求失败：$error');
    }
    // 响应体读取也有整体上限：JSON 端点都是小响应，卡住的连接直接放弃。
    String text;
    try {
      text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      throw ApiException(0, 'network', '响应读取失败：$error');
    }
    Map<String, dynamic>? json;
    if (text.isNotEmpty) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // 非 JSON 响应（网关错误页等）留空，按状态码报错。
      }
    }
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw ApiException(
        status,
        json?['error'] as String? ?? 'http_$status',
        json?['message'] as String? ?? '请求失败（HTTP $status）',
      );
    }
    return json ?? <String, dynamic>{};
  }

  /// 释放底层连接池。App 生命周期内只有一个实例，退出时不必显式调用。
  void dispose() {
    _client?.close(force: true);
    _client = null;
  }
}
