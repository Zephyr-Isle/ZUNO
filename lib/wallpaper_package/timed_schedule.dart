import 'dart:convert';

/// schedule.json（timed 类型）的解析模型。
///
/// 格式（规格）：
/// ```json
/// {
///   "rules": [ { "from": "06:00", "to": "18:00", "wallpaper": "slot_day" } ],
///   "default": "slot_morning",
///   "constraints": { "chargingOnly": false, "minIntervalMinutes": 30 }
/// }
/// ```
///
/// 纯 Dart（无 Flutter 依赖），导入校验与运行时展示共用。
class TimedRule {
  const TimedRule({
    required this.fromMinutes,
    required this.toMinutes,
    required this.slotName,
    required this.fromRaw,
    required this.toRaw,
  });

  /// 当日分钟数（[0, 1440)）。
  final int fromMinutes;
  final int toMinutes;
  final String slotName;
  final String fromRaw;
  final String toRaw;

  bool get overnight => fromMinutes > toMinutes;

  bool matches(int minutesOfDay) {
    if (fromMinutes < toMinutes) {
      return minutesOfDay >= fromMinutes && minutesOfDay < toMinutes;
    }
    if (fromMinutes > toMinutes) {
      // 跨午夜（如 18:00–06:00）。
      return minutesOfDay >= fromMinutes || minutesOfDay < toMinutes;
    }
    return false; // from == to 视为空窗口
  }

  Map<String, dynamic> toMap() => {
    'from': fromRaw,
    'to': toRaw,
    'wallpaper': slotName,
  };
}

class TimedSchedule {
  const TimedSchedule({
    required this.rules,
    required this.defaultSlot,
    required this.chargingOnly,
    required this.minIntervalMinutes,
  });

  final List<TimedRule> rules;
  final String defaultSlot;
  final bool chargingOnly;
  final int minIntervalMinutes;

  /// 当前时间应激活的 slot 名（充电约束由原生 Worker 判断）。
  String? resolveSlotName(int minutesOfDay) {
    for (final r in rules) {
      if (r.matches(minutesOfDay)) return r.slotName;
    }
    return defaultSlot.isEmpty ? null : defaultSlot;
  }
}

class TimedScheduleParser {
  TimedScheduleParser._();

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// 返回 (schedule, errors)；errors 非空即校验失败。
  static (TimedSchedule?, List<String>) parse(String raw) {
    final dynamic json;
    try {
      json = jsonDecode(raw);
    } catch (e) {
      return (null, ['schedule.json 不是合法 JSON: $e']);
    }
    if (json is! Map) return (null, ['schedule.json 顶层必须是对象']);

    final errors = <String>[];
    final rulesRaw = json['rules'];
    if (rulesRaw is! List) {
      return (null, ['schedule.rules 必须是数组']);
    }
    final rules = <TimedRule>[];
    for (var i = 0; i < rulesRaw.length; i++) {
      final r = rulesRaw[i];
      if (r is! Map) {
        errors.add('rules[$i] 必须是对象');
        continue;
      }
      final from = r['from'];
      final to = r['to'];
      final slot = r['wallpaper'];
      if (from is! String || !_hhmm.hasMatch(from)) {
        errors.add('rules[$i].from 必须是 HH:mm，实际: $from');
        continue;
      }
      if (to is! String || !_hhmm.hasMatch(to)) {
        errors.add('rules[$i].to 必须是 HH:mm，实际: $to');
        continue;
      }
      if (slot is! String || slot.isEmpty) {
        errors.add('rules[$i].wallpaper 必须是非空字符串');
        continue;
      }
      rules.add(
        TimedRule(
          fromMinutes: _minutes(from),
          toMinutes: _minutes(to),
          slotName: slot,
          fromRaw: from,
          toRaw: to,
        ),
      );
    }
    final constraintsRaw = json['constraints'];
    final constraints = constraintsRaw is Map
        ? Map<String, dynamic>.from(constraintsRaw)
        : <String, dynamic>{};
    final defaultSlot = json['default'];
    if (defaultSlot != null && defaultSlot is! String) {
      errors.add('default 必须是字符串');
    }
    // 任何一条规则出错即整体无效（导入校验的语义：要么合法要么拒绝）。
    if (errors.isNotEmpty) return (null, errors);
    final schedule = TimedSchedule(
      rules: rules,
      defaultSlot: defaultSlot is String ? defaultSlot : '',
      chargingOnly: constraints['chargingOnly'] == true,
      minIntervalMinutes: _toInt(constraints['minIntervalMinutes']),
    );
    return (schedule, errors);
  }

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static int _toInt(Object? v) => v is num && v.toInt() == v ? v.toInt() : 0;
}
