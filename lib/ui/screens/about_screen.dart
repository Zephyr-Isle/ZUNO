import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:url_launcher/url_launcher.dart';

import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// 关于页：应用信息、简介、QQ 交流群入口。
///
/// 面向用户的产品信息页——不放实现架构等面向开发者的硬核内容。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _qqGroupUrl = 'https://qm.qq.com/q/So22cAu4IS';

  Future<void> _openQqGroup(BuildContext context) async {
    final uri = Uri.parse(_qqGroupUrl);
    try {
      // externalApplication：优先拉起 QQ（链接是加群短链），否则走浏览器。
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch rejected');
    } catch (_) {
      // 设备上没有任何可处理 https 的应用（极少见）：复制链接兜底。
      await Clipboard.setData(const ClipboardData(text: _qqGroupUrl));
      if (context.mounted) {
        lgw.GlassToast.show(
          context,
          message: '群链接已复制，可在 QQ 中粘贴加入',
          type: lgw.GlassToastType.info,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // extendBody 后内容滚进玻璃导航栏下方由 soft 边缘淡出收尾。
    final mediaQuery = MediaQuery.of(context);
    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: const Text('关于'),
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: '返回',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Material(
        type: MaterialType.transparency,
        child: ListView(
          // 顶部让出状态栏 + app bar。
          padding: EdgeInsets.fromLTRB(
            16,
            mediaQuery.padding.top + 44 + 12,
            16,
            mediaQuery.padding.bottom + 24,
          ),
          children: [
            const SizedBox(height: 8),
            // 应用标识：图标 + 名称 + 版本。
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ZUNO',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 简介：一句话讲清楚应用做什么。
            GlassSurface(
              child: Text(
                '让桌面动起来。ZUNO 提供视频、深度视差、HTML 交互和定时切换'
                '四种动态壁纸：导入壁纸包、一键应用，即可拥有会动的桌面。',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            // QQ 交流群入口。
            GlassSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: appIcon(AppIcons.group, color: scheme.primary),
                title: const Text('QQ 交流群'),
                subtitle: const Text('反馈问题、分享与获取壁纸包'),
                trailing: appIcon(
                  AppIcons.chevronRight,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _openQqGroup(context),
              ),
            ),
            const SizedBox(height: 16),
            // 功能亮点（用户视角，非实现架构）。
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('功能亮点', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _bullet(context, '视频壁纸', '流畅播放，默认静音，可调速度与音量'),
                  _bullet(context, '深度视差', '随手机倾斜产生立体层次感'),
                  _bullet(context, 'HTML 交互壁纸', '支持点击互动的网页壁纸'),
                  _bullet(context, '定时切换', '白天夜晚自动换不同的壁纸'),
                  _bullet(context, '性能档位', '高 / 中 / 低，兼顾观感与省电'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Made with ZUNO',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String title, String desc) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: appIcon(AppIcons.dot, size: 8, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$title：',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: desc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
