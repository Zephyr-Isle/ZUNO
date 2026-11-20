import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:zuno/app.dart';
import 'package:zuno/core/zuno_paths.dart';
import 'package:zuno/services/library_repository.dart';
import 'package:zuno/services/platform_bridge.dart';
import 'package:zuno/services/remote_api.dart';
import 'package:zuno/state/catalog_controller.dart';
import 'package:zuno/state/endpoint_controller.dart';
import 'package:zuno/state/library_controller.dart';
import 'package:zuno/state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 液态玻璃组件库：预加载/预热 fragment shader（异步磁盘 IO，避免首帧白闪）。
  await LiquidGlassWidgets.initialize();
  // Hive（壁纸库索引）：initFlutter 内部使用 path_provider 定位目录。
  await Hive.initFlutter();
  final repository = await LibraryRepository.open();
  final apiLevel = await ZunoNative.deviceApiLevel();
  final controller = LibraryController(repository, apiLevel);
  // 云端目录：共用同一个 HttpClient 连接池。壁纸库地址用户可改，
  // 启动时先恢复上次保存的值（读通道失败则用编译期默认值）。
  final api = RemoteApi();
  final endpoint = await EndpointController.load(api);
  final catalog = CatalogController(api);
  // 外观模式必须在首帧前读取：先渲染浅色再切深色会白闪一下。
  final themeController = await ThemeController.load();
  // 清理上次进程死亡遗留的导入暂存目录（正常路径导入完成即删；
  // 被 kill 打断时会留下孤儿目录，占着视频包大小的磁盘空间）。
  unawaited(_cleanupStaleStaging());
  try {
    await controller.refresh();
  } catch (_) {
    // 首帧前的平台通道调用失败（极少见）不阻断启动：
    // 库列表为空态展示，回到前台时 WidgetsBindingObserver 会再次刷新。
  }
  // 全应用玻璃主题：iOS 27 材质 + 一层明显可见的雾。
  //
  // 不传 brightness：玻璃跟随 MaterialApp 的 ThemeMode，由
  // brightnessResolver: Theme.maybeBrightnessOf 解析明暗变体。
  //
  // 不能再用 `GlassThemeData.simple(...).copyWith(light: ...)`：copyWith 会
  // 把 simple 生成的 light/dark 变体整体替换掉，之前写进去的 blur / 折射 /
  // 高光全部被丢弃，这就是为什么玻璃只剩一层平涂半透明。这里直接构造变体。
  //
  // 雾 = `frost`（宽高斯云）+ `frostOpacity`（云覆盖度）。包默认 14 / 0.73
  // 是按 56pt 原生控件标定的，放到 ZUNO 的大卡片和近白页面底色上几乎看不出
  // 层次；提到 24 / 0.9 后，背景文字变成淡淡的雾中残影，玻璃才有厚度。
  // `blur` 保持很小，让残影仍有边缘（iOS 27 的“cloud + ghost”结构）。
  // `indicatorSettings` 单独给透镜：选中胶囊要清透有高光，不能一起糊掉。
  final glassTheme = GlassThemeData(
    style: GlassStyle.ios27,
    light: GlassThemeVariant(
      settings: GlassThemeSettings.ios27Light.copyWith(
        glassColor: const Color(0xA6FAFBFD),
        saturation: 1.35,
        blur: 0.9,
        blurWeight: 0.8,
        frost: 24,
        frostOpacity: 0.90,
        frostClamp: 0.38,
        frostWeight: 2.2,
        thickness: 34,
        refractiveIndex: 1.30,
        chromaticAberration: 0.05,
        lightIntensity: 0.12,
        ambientStrength: 0.04,
        edgeAbsorption: 0.05,
        rimShade: 1,
        rimLight: 1.15,
        bodyShade: 0.03,
        shadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      indicatorSettings: const GlassThemeSettings(
        glassColor: Color(0x4DFFFFFF),
        thickness: 30,
        refractiveIndex: 1.30,
        saturation: 1.5,
        rimShade: 0.8,
        rimLight: 1.2,
      ),
      borderRadius: 28,
    ),
    dark: GlassThemeVariant(
      // 暗色玻璃按 iOS 27 暗色导航校准：盘面要「深」，不是「白」。
      // 之前沿用浅色的雾配方（frostOpacity 0.92 + frostWeight 1.1 +
      // 17% 白玻璃），白色雾云把盘面糊成奶灰（发白），而选中胶囊没有
      // frost 反而比盘面更黑。现在大幅降雾、降白玻璃透明度，让盘面
      // 深下去；指示胶囊用更高白玻璃提亮成「透镜」，比盘面亮一档。
      settings: GlassThemeSettings.ios27Dark.copyWith(
        glassColor: const Color(0x14FFFFFF),
        saturation: 1.4,
        blur: 0.9,
        blurWeight: 2.5,
        frost: 24,
        frostOpacity: 0.55,
        frostClamp: -0.45,
        frostWeight: 0.6,
        thickness: 34,
        refractiveIndex: 1.30,
        chromaticAberration: 0.03,
        lightIntensity: 0.08,
        ambientStrength: 0.04,
        edgeAbsorption: 0.05,
        rimShade: 1,
        rimShadeEnds: 0,
        rimLight: 1.15,
        bodyShade: 0.30,
        shadowElevation: 0,
      ),
      indicatorSettings: const GlassThemeSettings(
        glassColor: Color(0x42FFFFFF),
        thickness: 30,
        refractiveIndex: 1.30,
        saturation: 1.4,
        rimShade: 0.6,
        rimLight: 1.25,
      ),
      borderRadius: 28,
    ),
  );
  runApp(
    LiquidGlassWidgets.wrap(
      theme: glassTheme,
      brightnessResolver: Theme.maybeBrightnessOf,
      child: ZunoApp(
        controller: controller,
        themeController: themeController,
        endpoint: endpoint,
        catalog: catalog,
      ),
    ),
  );
}

/// 删除 import_tmp 下超过 1 小时的暂存目录（导入全程通常分钟级，
/// 活跃导入的目录不会被误删）。失败静默——清理不影响任何功能。
Future<void> _cleanupStaleStaging() async {
  try {
    final root = await ZunoPaths.stagingRoot();
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final entity in root.list()) {
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete(recursive: true);
      }
    }
  } catch (_) {
    // 清理失败不影响任何功能。
  }
}
