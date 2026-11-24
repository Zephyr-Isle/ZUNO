import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';

/// manifest.config[] 驱动的参数编辑器。
///
/// 支持四种参数类型（规格）：float（液态玻璃滑杆）、int（玻璃滑杆取整）、
/// bool（玻璃开关）、color（hex 文本 + 预设色块）。
/// 值以 `Map<String, Object?>` 形式保存，应用壁纸时经 jsonEncode 写入原生 prefs。
class ConfigEditor extends StatelessWidget {
  const ConfigEditor({
    super.key,
    required this.params,
    required this.values,
    required this.onChanged,
  });

  /// manifest.config[] 的原始定义列表（List<Map>）。
  final List<Map<String, dynamic>> params;

  /// 当前取值（key → value）。编辑器保证类型与参数定义一致。
  final Map<String, Object?> values;
  final ValueChanged<Map<String, Object?>> onChanged;

  void _update(String key, Object? value) {
    final next = Map<String, Object?>.from(values);
    next[key] = value;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (params.isEmpty) {
      return Text(
        ZunoLocalizations.of(context).noParameters,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final p in params) _buildParam(context, p)],
    );
  }

  Widget _buildParam(BuildContext context, Map<String, dynamic> p) {
    final scheme = Theme.of(context).colorScheme;
    final key = p['key'] as String;
    final type = p['type'] as String;
    final label = (p['label'] as String?) ?? key;
    final note = p['note'] as String?;
    switch (type) {
      case 'float':
        final min = (p['min'] as num?)?.toDouble() ?? 0.0;
        final max = (p['max'] as num?)?.toDouble() ?? 1.0;
        final value =
            (values[key] as num?)?.toDouble() ??
            (p['default'] as num?)?.toDouble() ??
            min;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(label), Text(value.toStringAsFixed(2))],
            ),
            const SizedBox(height: 4),
            lgw.GlassSlider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              activeColor: scheme.primary,
              inactiveColor: scheme.primary.withValues(alpha: 0.16),
              thumbColor: Colors.white,
              quality: lgw.GlassQuality.premium,
              useOwnLayer: true,
              onChanged: (v) => _update(key, v),
            ),
            _note(context, note),
          ],
        );
      case 'int':
        final min = (p['min'] as num?)?.toInt() ?? 0;
        final max = (p['max'] as num?)?.toInt() ?? 100;
        final value =
            (values[key] as num?)?.toInt() ??
            (p['default'] as num?)?.toInt() ??
            min;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(label), Text('$value')],
            ),
            const SizedBox(height: 4),
            lgw.GlassSlider(
              value: value.clamp(min, max).toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) <= 0 ? null : max - min,
              activeColor: scheme.primary,
              inactiveColor: scheme.primary.withValues(alpha: 0.16),
              thumbColor: Colors.white,
              quality: lgw.GlassQuality.premium,
              useOwnLayer: true,
              onChanged: (v) => _update(key, v.round()),
            ),
            _note(context, note),
          ],
        );
      case 'bool':
        final value = (values[key] as bool?) ?? p['default'] as bool? ?? false;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          note,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              lgw.GlassSwitch(
                value: value,
                onChanged: (v) => _update(key, v),
                activeColor: const Color(0xFF34C759),
                quality: lgw.GlassQuality.premium,
                useOwnLayer: true,
              ),
            ],
          ),
        );
      case 'color':
        final value =
            (values[key] as String?) ?? p['default'] as String? ?? '#FFFFFF';
        return _ColorField(
          key: ValueKey('color_$key'),
          label: label,
          note: note,
          value: value,
          onCommitted: (v) => _update(key, v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _note(BuildContext context, String? note) {
    if (note == null) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// hex 颜色串 → Color（非法输入返回灰色占位）。
/// 提为文件级函数：ConfigEditor 与 _ColorField 都要用。
/// 输入直接来自 TextField 原文（色块在 build 里解析），非 hex 字符随时可能
/// 出现——长度恰好 6/8 位但含非法字符时 int.parse 会抛 FormatException，
/// 在 build 里抛异常会把整个详情页打成 ErrorWidget（连纠正输入的输入框都
/// 被替换掉）。必须在此兜底，非法输入一律回落占位色。
final _hexColorPattern = RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

Color _tryParseColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (!_hexColorPattern.hasMatch(cleaned)) return Colors.grey;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return Colors.grey;
  return cleaned.length == 6 ? Color(0xFF000000 | value) : Color(value);
}

/// 颜色参数编辑器（StatefulWidget：TextEditingController 需要随外部值同步）。
///
/// 之前用 `initialValue`：TextFormField 只在首次构建读取它，外部值变化后
/// 输入框文本不更新，出现“显示值 ≠ 已提交值”。现在用 controller +
/// didUpdateWidget 双向同步（仅在外部值与当前文本不同时回写，避免光标跳动）。
class _ColorField extends StatefulWidget {
  const _ColorField({
    super.key,
    required this.label,
    required this.note,
    required this.value,
    required this.onCommitted,
  });

  final String label;
  final String? note;
  final String value;
  final ValueChanged<String> onCommitted;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  static final _hexPattern = RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

  @override
  void didUpdateWidget(covariant _ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化（如重置为 default）且用户没有正在编辑同一文本时才回写。
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: '#RRGGBB',
                ),
                onChanged: (v) {
                  if (_hexPattern.hasMatch(v)) widget.onCommitted(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _tryParseColor(_controller.text),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22000000)),
              ),
            ),
          ],
        ),
        if (widget.note != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.note!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
