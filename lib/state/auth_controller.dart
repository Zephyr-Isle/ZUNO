import 'package:flutter/foundation.dart';

import 'package:zuno/l10n/zuno_strings.dart';
import 'package:zuno/models/remote_wallpaper.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/remote_api.dart';

/// 账号会话状态。
///
/// token 落盘走原生 `zuno/native`（与其余配置同一条通道），Dart 侧不引入
/// shared_preferences：一是原生是唯一存储方，二是这个 token 只用于 HTTP
/// 头，没有任何原生组件会去读它，放在同一个应用私有目录即可。
class AuthController extends ChangeNotifier {
  AuthController(this._api, [this._session]);

  final RemoteApi _api;

  AuthSession? _session;
  bool _busy = false;
  String? _error;

  AuthSession? get session => _session;
  bool get busy => _busy;
  String? get error => _error;

  /// 会话有效才算登录：token 到期后按未登录处理，后续请求不会带着过期票。
  bool get signedIn => _session != null && !_session!.expired;

  String get email => _session?.email ?? '';

  /// 会话剩余天数（用于“我的”页展示；已过期返回 0）。
  int get daysLeft {
    final session = _session;
    if (session == null) return 0;
    final left = session.expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return 0;
    return (left / Duration.millisecondsPerDay).ceil();
  }

  /// 启动时恢复上次会话。过期的直接清掉，避免带着死票请求。
  static Future<AuthController> load(RemoteApi api) async {
    Map<String, dynamic>? stored;
    try {
      stored = await ZunoNative.loadAuth();
    } catch (_) {
      stored = null;
    }
    if (stored == null) return AuthController(api);
    final token = stored['token'] as String?;
    if (token == null || token.isEmpty) return AuthController(api);
    final session = AuthSession(
      token: token,
      userId: stored['userId'] as String? ?? '',
      email: stored['email'] as String? ?? '',
      expiresAt: (stored['expiresAt'] as num?)?.toInt() ?? 0,
    );
    if (session.expired) {
      await ZunoNative.clearAuth();
      return AuthController(api);
    }
    return AuthController(api, session);
  }

  Future<bool> register({
    required String email,
    required String password,
  }) => _run(() => _api.register(email: email, password: password));

  Future<bool> login({
    required String email,
    required String password,
  }) => _run(() => _api.login(email: email, password: password));

  /// 退出登录：先清本地，再尽力通知服务端删 session。
  ///
  /// 顺序不能反：网络失败时用户仍然应该看到“已退出”，而不是卡在一个
  /// 删不掉的会话上。
  Future<void> logout() async {
    final token = _session?.token;
    _session = null;
    _error = null;
    notifyListeners();
    await ZunoNative.clearAuth();
    if (token != null) {
      try {
        await _api.logout(token);
      } catch (_) {
        // 服务端 session 到期后自行失效，这里失败无需打扰用户。
      }
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final session = await action();
      _session = session;
      await ZunoNative.saveAuth(
        token: session.token,
        userId: session.userId,
        email: session.email,
        expiresAt: session.expiresAt,
      );
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } catch (error) {
      _error = ZunoStrings.current.errOperationFailed(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
