import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'package:zuno/state/auth_controller.dart';
import 'package:zuno/ui/widgets/app_icons.dart';
import 'package:zuno/ui/widgets/glass_widgets.dart';

/// 登录 / 注册页。
///
/// 独立成页（而不是弹窗）：表单需要键盘、自动填充与错误留白，弹窗在
/// 小屏上会被键盘挤到没有可视区域。返回 `true` 表示已登录成功。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthController auth;

  /// 供“我的”“下载”等处复用：打开并以 bool 返回是否登录成功。
  static Future<bool> open(BuildContext context, AuthController auth) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => AuthScreen(auth: auth)),
    );
    return result ?? false;
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// 0 = 登录，1 = 注册。
  int _mode = 0;
  bool _obscure = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    // 切换登录/注册时清掉上一次的报错，避免把“该邮箱已注册”带到登录页。
    widget.auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMode(int index) {
    if (index == _mode) return;
    setState(() {
      _mode = index;
      _localError = null;
      _confirm.clear();
    });
    widget.auth.clearError();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _localError = '邮箱格式不正确');
      return;
    }
    if (password.length < 8) {
      setState(() => _localError = '密码长度需为 8–128 个字符');
      return;
    }
    if (_mode == 1 && password != _confirm.text) {
      setState(() => _localError = '两次输入的密码不一致');
      return;
    }
    setState(() => _localError = null);

    final ok = _mode == 1
        ? await widget.auth.register(email: email, password: password)
        : await widget.auth.login(email: email, password: password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = widget.auth.busy;
    final error = _localError ?? widget.auth.error;
    // extendBody 后内容滚进玻璃导航栏下方由 soft 边缘淡出收尾。
    final mediaQuery = MediaQuery.of(context);

    return lgw.GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarStyle: zunoStatusBarStyle(context),
      extendBody: true,
      appBar: lgw.GlassAppBar(
        title: Text(_mode == 0 ? '登录' : '注册'),
        leading: GlassCircleButton(
          icon: AppIcons.back,
          semanticLabel: '返回',
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Material(
        // GlassScaffold 是 Cupertino 骨架，TextField/Button 需要 Material ancestor。
        type: MaterialType.transparency,
        child: ListView(
          // 顶部让出状态栏 + app bar。
          padding: EdgeInsets.fromLTRB(
            16,
            mediaQuery.padding.top + 44 + 12,
            16,
            40,
          ),
          children: [
            lgw.GlassSegmentedControl(
              segments: const [
                lgw.GlassSegment(label: '登录', id: 'login'),
                lgw.GlassSegment(label: '注册', id: 'register'),
              ],
              selectedIndex: _mode,
              onSegmentSelected: _setMode,
              height: 44,
              quality: lgw.GlassQuality.standard,
              selectedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            GlassSurface(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: '邮箱',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: appIcon(
                          AppIcons.mail,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: _mode == 1
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (_mode == 0) _submit();
                    },
                    decoration: InputDecoration(
                      hintText: _mode == 1 ? '密码（至少 8 位）' : '密码',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: appIcon(
                          AppIcons.lock,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: appIcon(
                          _obscure ? AppIcons.view : AppIcons.viewOff,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (_mode == 1) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '再输入一次密码',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: appIcon(
                            AppIcons.lock,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  appIcon(AppIcons.error, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(fontSize: 12.5, color: scheme.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            GlassPrimaryButton(
              icon: _mode == 0 ? AppIcons.login : AppIcons.userCircle,
              label: busy
                  ? (_mode == 0 ? '正在登录…' : '正在创建…')
                  : (_mode == 0 ? '登录' : '创建账号'),
              // 玻璃按钮没有 disabled 态：忙碌时挂空回调，避免重复提交。
              onPressed: busy ? () {} : _submit,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '账号用于在线壁纸库与下载票据。'
                '上传壁纸与用户管理属于管理端功能（Admin Secret），客户端不提供入口。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
