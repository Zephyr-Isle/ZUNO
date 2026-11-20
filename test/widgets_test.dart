import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/models/library_entry.dart';
import 'package:zuno/ui/widgets/config_editor.dart';
import 'package:zuno/ui/widgets/package_card.dart';
import 'package:zuno/ui/widgets/type_badge.dart';

/// 纯 UI 单元测试（不触达 Platform Channel / 文件系统）。
void main() {
  // 一个不含 thumbnail 的测试条目（PackageCard 走占位图标路径，不读磁盘）。
  LibraryEntry entry({bool active = false}) => LibraryEntry(
    id: 'com.test.sample',
    version: '1.0.0',
    title: '测试壁纸',
    authorHandle: 'tester',
    type: 'video',
    packageDir: '/unused',
    entry: 'content/main.mp4',
    thumbnailPath: null,
    performanceHint: 'medium',
    configParams: const [],
    capabilities: const {},
    installedAt: 0,
    scheduleRules: const [],
    scheduleDefaultSlot: '',
    slotIds: const [],
  );

  testWidgets('ConfigEditor：bool 参数开关触发 onChanged', (tester) async {
    Map<String, Object?>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            params: const [
              {'key': 'muted', 'type': 'bool', 'label': '静音', 'default': false},
            ],
            values: const {},
            onChanged: (v) => captured = v,
          ),
        ),
      ),
    );

    expect(find.text('静音'), findsOneWidget);
    expect(find.byType(lgw.GlassSwitch), findsOneWidget);

    await tester.tap(find.byType(lgw.GlassSwitch));
    expect(captured, isNotNull);
    expect(captured!['muted'], true);
  });

  testWidgets('ConfigEditor：float 参数渲染滑杆并带上限标签', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            params: const [
              {
                'key': 'playback_speed',
                'type': 'float',
                'label': '播放速度',
                'min': 0.5,
                'max': 2.0,
                'default': 1.0,
              },
            ],
            values: const {},
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('播放速度'), findsOneWidget);
    expect(find.byType(lgw.GlassSlider), findsOneWidget);
    expect(find.text('1.00'), findsOneWidget);
  });

  testWidgets('PackageCard：激活态显示徽标，类型徽标正确', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 320,
            child: PackageCard(entry: entry(), active: true, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试壁纸'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('v1.0.0 · tester'), findsOneWidget);
    // 类型徽标由 TypeBadge 渲染（video → “视频”）。
    expect(find.byType(TypeBadge), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
  });

  testWidgets('PackageCard：点击回调触发', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 320,
            child: PackageCard(
              entry: entry(),
              active: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('测试壁纸'));
    expect(tapped, isTrue);
  });
}
