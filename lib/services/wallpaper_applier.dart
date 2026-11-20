import 'dart:convert';

import 'package:zuno/models/library_entry.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/wallpaper_package/timed_schedule.dart';

/// 应用壁纸的编排层。
///
/// “应用”分两步：
/// 1. 写入激活状态（id/type/dir/entry/config）——引擎据此渲染；
/// 2. 打开系统动态壁纸预览页让用户确认——普通应用没有 SET_WALLPAPER_COMPONENT
///    系统签名权限，这是唯一的设置途径（规格与 README 均有说明）。
class WallpaperApplier {
  const WallpaperApplier();

  Future<ApplyResult> apply(
    LibraryEntry entry,
    Map<String, Object?> configValues,
  ) async {
    String id = entry.id;
    String type = entry.type;
    String dir = entry.packageDir;
    String entryPath = entry.entry;
    String? timedParentDir;

    if (entry.type == 'timed') {
      // timed 包本身不渲染：应用时解析出“当前时段”的 slot 子包作为激活渲染单元，
      // timedParentDir 记录父包根目录，交给 WorkManager 周期任务后续切换。
      final slot = await ZunoNative.resolveTimedSlot(entry.packageDir);
      if (slot == null) {
        return const ApplyResult.failure('未能解析出当前时段的子壁纸（可能受充电约束限制，请连接充电器后重试）');
      }
      id = slot['slotId'] as String? ?? id;
      type = slot['type'] as String? ?? type;
      dir = slot['slotDir'] as String? ?? dir;
      entryPath = slot['entry'] as String? ?? entryPath;
      timedParentDir = entry.packageDir;
    }

    await ZunoNative.setActiveWallpaper(
      id: id,
      type: type,
      dir: dir,
      entry: entryPath,
      configJson: jsonEncode(configValues),
      capabilitiesJson: jsonEncode(entry.capabilities),
      timedParentDir: timedParentDir,
    );

    final launched = await ZunoNative.launchWallpaperPreview();
    return ApplyResult.success(launched);
  }

  /// timed 预览：在指定时刻激活对应 slot。
  /// 不拉起系统选择器——ZUNO 已是活跃组件时引擎静默热切换；
  /// 下次 WorkManager 调度检查时恢复实际时段。
  /// 返回 slot id；解析失败返回 null。
  Future<String?> previewTimedSlot(LibraryEntry entry, int minutesOfDay) async {
    final slot = await ZunoNative.resolveTimedSlot(
      entry.packageDir,
      hour: minutesOfDay ~/ 60,
      minute: minutesOfDay % 60,
    );
    if (slot == null) return null;
    await ZunoNative.setActiveWallpaper(
      id: slot['slotId'] as String? ?? '',
      type: slot['type'] as String? ?? '',
      dir: slot['slotDir'] as String? ?? '',
      entry: slot['entry'] as String? ?? '',
      // 原生返回父包已持久化的用户配置（resolveTimedSlot 注入）：
      // 之前固定传 '{}' 会把用户调好的参数覆盖成默认值，预览一次即丢失。
      configJson: slot['configJson'] as String? ?? '{}',
      capabilitiesJson: slot['capabilitiesJson'] as String? ?? '{}',
      timedParentDir: entry.packageDir,
    );
    // 返回 slot 目录短名（slot_day/slot_night）供 UI 标签展示：
    // slotId 是全限定 id（com.x.y.slot_night），放不进调度窗口标签行。
    return slot['slotName'] as String? ?? slot['slotId'] as String?;
  }

  /// 供详情页展示”timed 当前时段”（不含充电约束的纯时间解析）。
  static String? currentTimedSlotName(LibraryEntry entry) {
    if (entry.type != 'timed' || entry.scheduleRules.isEmpty) return null;
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final schedule = TimedSchedule(
      rules: entry.scheduleRules
          .map((r) => _ruleFromMap(r))
          .whereType<TimedRule>()
          .toList(),
      defaultSlot: entry.scheduleDefaultSlot,
      chargingOnly: false,
      minIntervalMinutes: 0,
    );
    return schedule.resolveSlotName(minutes);
  }

  static TimedRule? _ruleFromMap(Map<String, dynamic> raw) {
    final from = raw['from'] as String?;
    final to = raw['to'] as String?;
    final slot = raw['wallpaper'] as String?;
    if (from == null || to == null || slot == null) return null;
    int minutes(String hhmm) {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    return TimedRule(
      fromMinutes: minutes(from),
      toMinutes: minutes(to),
      slotName: slot,
      fromRaw: from,
      toRaw: to,
    );
  }
}

class ApplyResult {
  const ApplyResult.failure(this.message)
    : success = false,
      previewLaunched = false;

  const ApplyResult.success(this.previewLaunched)
    : success = true,
      message = null;

  final bool success;
  final String? message;
  final bool previewLaunched;
}
