import 'package:flutter/foundation.dart';

import 'package:zuno/services/platform_bridge.dart';

/// 主壳 UI 偏好（底部玻璃 TAB 显隐）。
///
/// 为什么可配：底部 TAB 占掉 102pt + 安全区，想要无遮挡流式布局的用户
/// 可以隐藏它，顶栏按钮会接管「我的壁纸 / 壁纸库」的切换入口。
/// 配置落在原生 `zuno_config`（`app.show_tab_bar`），与其余设置同一条通道。
class ShellPrefsController extends ChangeNotifier {
  ShellPrefsController._(this._showTabBar);

  bool _showTabBar;

  bool get showTabBar => _showTabBar;

  /// 启动时读取；没存过或通道失败都按默认值（隐藏）处理。
  static Future<ShellPrefsController> load() async {
    bool stored;
    try {
      stored = await ZunoNative.getShowTabBar();
    } catch (_) {
      stored = false;
    }
    return ShellPrefsController._(stored);
  }

  /// 保存显隐。先写原生（重启后的事实来源），成功后再改内存并广播：
  /// 顺序反过来时，通道写入失败会让内存指向新值、重启后却跳回旧值，
  /// UI 与持久化状态不一致。
  Future<void> setShowTabBar(bool visible) async {
    if (visible == _showTabBar) return;
    await ZunoNative.setShowTabBar(visible);
    _showTabBar = visible;
    notifyListeners();
  }
}
