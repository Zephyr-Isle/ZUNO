import 'package:flutter/foundation.dart';

import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/remote_api.dart';

/// 壁纸库地址（后端 base URL）的运行时配置。
///
/// ZUNO 不内置任何云端服务：地址指向用户自己部署的 zuno-api
/// （Cloudflare Workers 或 Docker 自托管，见 README「后端部署」）。
/// 未配置时壁纸库显示引导去设置的空态，不会发起任何请求。
/// 配置落在原生 `zuno_config`（`library.base_url`），与其余设置同一条通道。
class EndpointController extends ChangeNotifier {
  EndpointController(this._api, this._url);

  final RemoteApi _api;
  String _url;

  String get url => _url;

  /// 未配置状态（空字符串）。
  bool get isConfigured => _url.isNotEmpty;

  /// 启动时读取；没存过或存的值非法就保持未配置。
  static Future<EndpointController> load(RemoteApi api) async {
    String? stored;
    try {
      stored = await ZunoNative.getLibraryUrl();
    } catch (_) {
      stored = null;
    }
    final url = normalize(stored) ?? '';
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

  /// 清空地址回到未配置状态。绕过 [setUrl] 的非空校验：
  /// 「填错了想暂时停用」是合法操作，壁纸库会显示引导空态。
  Future<void> clearUrl() async {
    if (_url.isEmpty) return;
    // 与 [setUrl] 相同的写入顺序：先原生后内存，保证两端一致。
    await ZunoNative.setLibraryUrl('');
    _url = '';
    _api.updateBaseUrl('');
    notifyListeners();
  }
}
