import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/state/auth_controller.dart';
import 'package:zuno/ui/screens/auth_screen.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// “我的”页：账号状态 + 管理功能说明。
///
/// 这里只放**个人**的事：登录/登出与会话信息。上传壁纸与用户管理是
/// 管理端能力（依赖 ADMIN_SECRET 与 WebDAV 直传），客户端刻意不提供
/// 入口——把管理面暴露在消费者 App 里，等于让每个装机用户都持有一把
/// 能改整个库的钥匙。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await lgw.GlassDialog.show<bool>(
      context: context,
      title: '退出登录？',
      message: '退出后需要重新登录才能下载在线壁纸；已安装的壁纸不受影响。',
      actions: [
        lgw.GlassDialogAction(
          label: '取消',
          onPressed: () => Navigator.pop(context, false),
        ),
        lgw.GlassDialogAction(
          label: '退出登录',
          isDestructive: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (confirmed == true) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final signedIn = auth.signedIn;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _AccountCard(auth: auth),
            if (!signedIn) ...[
              const SizedBox(height: 14),
              GlassPrimaryButton(
                icon: AppIcons.login,
                label: '登录 / 注册',
                onPressed: () => AuthScreen.open(context, auth),
              ),
            ],
            if (signedIn) ...[
              const SizedBox(height: 14),
              lgw.GlassGroupedSection(
                header: const Text('账号'),
                shape: glassShape(radius: 28),
                quality: lgw.GlassQuality.standard,
                children: [
                  lgw.GlassListTile(
                    leading: appIcon(AppIcons.mail),
                    leadingIconColor: scheme.primary,
                    title: const Text('邮箱'),
                    subtitle: Text(auth.email),
                  ),
                  lgw.GlassListTile(
                    leading: appIcon(AppIcons.clock),
                    leadingIconColor: scheme.primary,
                    title: const Text('会话有效期'),
                    subtitle: Text('剩余 ${auth.daysLeft} 天，到期后需重新登录'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              lgw.GlassGroupedSection(
                shape: glassShape(radius: 28),
                quality: lgw.GlassQuality.standard,
                children: [
                  lgw.GlassListTile(
                    leading: appIcon(AppIcons.logout),
                    leadingIconColor: scheme.error,
                    title: Text(
                      '退出登录',
                      style: TextStyle(color: scheme.error),
                    ),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const _ManagementSection(),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedIn = auth.signedIn;
    final email = auth.email;
    // 头像占位：邮箱首字母。空邮箱（理论上不会出现）回落到图标。
    final initial = email.isEmpty ? null : email.substring(0, 1).toUpperCase();
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  zunoAccent,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.18),
                    zunoAccent,
                  ),
                ],
              ),
            ),
            child: initial != null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : appIcon(AppIcons.userCircle, size: 28, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  signedIn ? email : '未登录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signedIn
                      ? '免费账号 · 剩余 ${auth.daysLeft} 天'
                      : '登录后可下载在线壁纸，浏览不受限',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 管理功能说明：明确告诉用户这些能力不在客户端，避免“功能缺失”的错觉。
class _ManagementSection extends StatelessWidget {
  const _ManagementSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = Text(
      '管理端',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
    return lgw.GlassGroupedSection(
      header: const Text('管理功能'),
      footer: const Text(
        '上传与会话管理依赖服务端的 ADMIN_SECRET：壁纸包由管理端直接写入 WebDAV，'
        '再调用 /api/admin/sync 落地元数据，全程不经过客户端。',
      ),
      shape: glassShape(radius: 28),
      quality: lgw.GlassQuality.standard,
      children: [
        lgw.GlassListTile(
          leading: appIcon(AppIcons.upload),
          leadingIconColor: scheme.primary.withValues(alpha: 0.6),
          title: const Text('上传壁纸'),
          subtitle: const Text('WebDAV 直传 + 后台同步'),
          trailing: badge,
        ),
        lgw.GlassListTile(
          leading: appIcon(AppIcons.group),
          leadingIconColor: scheme.primary.withValues(alpha: 0.6),
          title: const Text('用户管理'),
          subtitle: const Text('D1 users 表，仅管理后台'),
          trailing: badge,
        ),
      ],
    );
  }
}
