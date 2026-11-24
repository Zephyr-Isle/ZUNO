import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/l10n/zuno_localizations.dart';
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
    final s = ZunoLocalizations.of(context);
    final confirmed = await lgw.GlassDialog.show<bool>(
      context: context,
      title: s.logoutTitle,
      message: s.logoutBody,
      actions: [
        lgw.GlassDialogAction(
          label: s.cancel,
          onPressed: () => Navigator.pop(context, false),
        ),
        lgw.GlassDialogAction(
          label: s.logout,
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
        final s = ZunoLocalizations.of(context);
        final signedIn = auth.signedIn;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _AccountCard(auth: auth),
            if (!signedIn) ...[
              const SizedBox(height: 14),
              GlassPrimaryButton(
                icon: AppIcons.login,
                label: s.loginRegister,
                onPressed: () => AuthScreen.open(context, auth),
              ),
            ],
            if (signedIn) ...[
              const SizedBox(height: 14),
              lgw.GlassGroupedSection(
                header: Text(s.account),
                shape: glassShape(radius: 28),
                quality: lgw.GlassQuality.standard,
                children: [
                  lgw.GlassListTile(
                    leading: appIcon(AppIcons.mail),
                    leadingIconColor: scheme.primary,
                    title: Text(s.email),
                    subtitle: Text(auth.email),
                  ),
                  lgw.GlassListTile(
                    leading: appIcon(AppIcons.clock),
                    leadingIconColor: scheme.primary,
                    title: Text(s.sessionValidity),
                    subtitle: Text(s.sessionDaysLeft(auth.daysLeft)),
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
                      s.logout,
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
    final s = ZunoLocalizations.of(context);
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
                  signedIn ? email : s.notSignedIn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signedIn
                      ? s.freeAccountDays(auth.daysLeft)
                      : s.loginToDownload,
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
    final s = ZunoLocalizations.of(context);
    final badge = Text(
      s.adminBadge,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
    return lgw.GlassGroupedSection(
      header: Text(s.management),
      footer: Text(s.managementFooter),
      shape: glassShape(radius: 28),
      quality: lgw.GlassQuality.standard,
      children: [
        lgw.GlassListTile(
          leading: appIcon(AppIcons.upload),
          leadingIconColor: scheme.primary.withValues(alpha: 0.6),
          title: Text(s.uploadWallpaper),
          subtitle: Text(s.uploadSubtitle),
          trailing: badge,
        ),
        lgw.GlassListTile(
          leading: appIcon(AppIcons.group),
          leadingIconColor: scheme.primary.withValues(alpha: 0.6),
          title: Text(s.userManagement),
          subtitle: Text(s.userManagementSubtitle),
          trailing: badge,
        ),
      ],
    );
  }
}
