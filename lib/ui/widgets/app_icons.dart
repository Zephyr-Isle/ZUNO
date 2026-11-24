import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// 全应用统一使用 HugeIcons（stroke-rounded 风格）。
///
/// `hugeicons` 4.x 的图标数据是 SVG 路径列表，不是 `IconData`，所以这里
/// 用 [AppIconData] 作为类型别名，并集中映射本应用用到的图标。
typedef AppIconData = List<List<dynamic>>;

class AppIcons {
  AppIcons._();

  static const back = HugeIcons.strokeRoundedArrowLeft01;
  // 设置入口用真正的齿轮（Settings02），与 iOS 设置图标语义一致；
  // 原来的滑杆图标留给“参数/调节”类入口。
  static const settings = HugeIcons.strokeRoundedSettings02;
  static const sliders = HugeIcons.strokeRoundedSlidersHorizontal;
  static const video = HugeIcons.strokeRoundedVideo01;
  static const cpu = HugeIcons.strokeRoundedCpu;
  static const layers = HugeIcons.strokeRoundedLayers01;
  static const share = HugeIcons.strokeRoundedShare03;
  static const delete = HugeIcons.strokeRoundedTrash;
  static const wallpaper = HugeIcons.strokeRoundedWallpaper;
  static const image = HugeIcons.strokeRoundedImage01;
  static const photo = HugeIcons.strokeRoundedImage02;
  static const grid = HugeIcons.strokeRoundedGridView;
  static const user = HugeIcons.strokeRoundedUser;
  static const importBox = HugeIcons.strokeRoundedImport;
  static const check = HugeIcons.strokeRoundedCheck;
  static const clock = HugeIcons.strokeRoundedClock01;
  static const batteryFull = HugeIcons.strokeRoundedBatteryFull;
  static const batteryWarning = HugeIcons.strokeRoundedBatteryWarning;
  static const database = HugeIcons.strokeRoundedDatabase;
  static const info = HugeIcons.strokeRoundedInfo;
  static const language = HugeIcons.strokeRoundedLanguageCircle;
  static const chevronRight = HugeIcons.strokeRoundedChevronRight;
  static const group = HugeIcons.strokeRoundedUserGroup;
  static const dot = HugeIcons.strokeRoundedDot;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const fullscreen = HugeIcons.strokeRoundedFullScreen;
  static const externalLink = HugeIcons.strokeRoundedExternalLink;
  static const error = HugeIcons.strokeRoundedAlertCircle;

  // ---- 在线壁纸库 / 账号 ----
  static const download = HugeIcons.strokeRoundedDownload01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const cloud = HugeIcons.strokeRoundedCloudUpload;
  static const mail = HugeIcons.strokeRoundedMail01;
  static const lock = HugeIcons.strokeRoundedSquareLock02;
  static const logout = HugeIcons.strokeRoundedLogout01;
  static const login = HugeIcons.strokeRoundedLogin01;
  static const view = HugeIcons.strokeRoundedView;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const upload = HugeIcons.strokeRoundedUpload01;
  static const userCircle = HugeIcons.strokeRoundedUserCircle;
  static const shield = HugeIcons.strokeRoundedShield01;
  static const checkCircle = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const loading = HugeIcons.strokeRoundedLoading03;
  static const arrowDown = HugeIcons.strokeRoundedArrowDown01;
}

/// 构造一个 HugeIcon。颜色/尺寸留空时会自动继承父级 IconTheme，
/// 方便放进 `GlassIconButton` 等自带 IconTheme 的玻璃控件里。
Widget appIcon(AppIconData icon, {double? size, Color? color}) =>
    HugeIcon(icon: icon, size: size, color: color);
