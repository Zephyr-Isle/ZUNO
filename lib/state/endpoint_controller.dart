import 'package:flutter/foundation.dart';

import 'package:zuno/core/zuno_endpoint.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/remote_api.dart';

/// 壁纸库地址（后端 base URL）的运行时配置。
///
/// 为什么可配：zuno-api 是自托管的（Worker + D1 + WebDAV），每个人部署的
/// 域名都不一样；写死在编译期等于每次换后端都要重新发版。
/// 配置落在原生 `zuno_config`（`library.base_url`），与其余设置同一条通道。
class EndpointController extends ChangeNotifier {
  EndpointController(this._api, this._url);

  final RemoteApi _api;
  String _url;

  String get url => _url;

  /// 编译期默认值（[ZunoEndpoint.base]），用户改坏了可以一键回退。
  String get defaultUrl => ZunoEndpoint.base;

  bool get isDefault => _url == defaultUrl;

  /// 启动时读取；没存过或存的值非法就回落到默认地址。
  static Future<EndpointController> load(RemoteApi api) async {
    String? stored;
    try {
      stored = await ZunoNative.getLibraryUrl();
    } catch (_) {
      stored = null;
    }
    final url = normalize(stored) ?? ZunoEndpoint.base;
    api.updateBaseUrl(url);
    return EndpointController(api, url);
  }

  /// 只接受 http/https 绝对地址；末尾斜杠会被去掉（否则拼出 `//api/...`）。
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  /// 保存新地址。返回 null 表示成功，否则是给用户看的错误文案。
  Future<String?> setUrl(String raw) async {
    final next = normalize(raw);
    if (next == null) return '请填写完整地址，例如 https://api.example.com';
    if (next == _url) return null;
    // 先写原生（`library.base_url` 是重启后的事实来源），成功后再改内存并
    // 广播：顺序反过来时，通道写入失败会让内存指向新地址、重启后却跳回
    // 旧地址，UI 与持久化状态不一致。
    await ZunoNative.setLibraryUrl(next);
    _url = next;
    _api.updateBaseUrl(next);
    notifyListeners();
    return null;
  }

  Future<String?> resetToDefault() => setUrl(defaultUrl);
}
