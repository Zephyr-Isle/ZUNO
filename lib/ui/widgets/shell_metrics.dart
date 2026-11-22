import 'package:flutter/widgets.dart';

/// 主壳（MainShellScreen）各页共用的布局度量。
///
/// 底部玻璃 TAB 的占位高度 = barHeight 66 + verticalPadding 18×2 = 102，
/// 外壳 extendBody: true 时内容会钻进玻璃栏下方，滚动视图需要补出这段
/// 高度，让首屏内容与“到底了”提示落在栏外。
const double kGlassTabBarBlock = 102.0;

/// 底部内容净空：TAB 可见时让出玻璃栏 + 安全区（Android 手势条）；
/// 隐藏时只让出安全区 + 一点余量，列表最后一项不贴死屏幕底边。
double shellBottomClearance(
  BuildContext context, {
  required bool tabBarVisible,
}) {
  final safe = MediaQuery.paddingOf(context).bottom;
  return tabBarVisible ? kGlassTabBarBlock + safe : safe + 12.0;
}
