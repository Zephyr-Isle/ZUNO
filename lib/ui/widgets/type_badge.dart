import 'package:flutter/material.dart';

import 'package:zuno/l10n/zuno_localizations.dart';

/// 壁纸类型徽标（video / html / depth / timed）。
///
/// iOS 风格的“软标签”：淡色底 + 同色文字、无描边，比带边框的胶囊更轻。
/// 颜色是类型语义色（不是全局强调色），深浅主题各有一套提亮值。
class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final strings = ZunoLocalizations.of(context);
    final (label, lightColor, darkColor) = switch (type) {
      'video' => (
        strings.typeVideo,
        const Color(0xFF5B4BE0),
        const Color(0xFFB4A7FF),
      ),
      'html' => (
        strings.typeHtml,
        const Color(0xFF0B8578),
        const Color(0xFF5EEAD4),
      ),
      'depth' => (
        strings.typeDepth,
        const Color(0xFF1D6FE0),
        const Color(0xFF8CB8FF),
      ),
      'timed' => (
        strings.typeTimed,
        const Color(0xFFB45309),
        const Color(0xFFFCD34D),
      ),
      _ => (type, const Color(0xFF6E6E73), const Color(0xFFB8B8BE)),
    };
    final color = dark ? darkColor : lightColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.2 : 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
