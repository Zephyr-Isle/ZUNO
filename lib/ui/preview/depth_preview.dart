import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:zuno/l10n/zuno_localizations.dart';

/// 深度视差壁纸的 App 内预览（仅参考）。
///
/// 预览刻意做成 Widget 层的“整体平移”近似：真机壁纸走原生 OpenGL ES 的
/// 位移映射着色器（深度图驱动近景反向于背景移动），比这里的平移细腻得多；
/// 且传感器在壁纸运行时由原生 SensorManager 采集（sensors_plus 仅预览使用，
/// 避免常驻 Flutter 流带来的功耗）。
class DepthPreview extends StatefulWidget {
  const DepthPreview({
    super.key,
    required this.colorPath,
    this.strength = 0.06,
    this.expand = false,
  });

  final String colorPath;

  /// 视差强度（manifest.config 的 parallax_strength，与原生壁纸同源），
  /// 位移幅度按它缩放：0.06 → 24px 基准。
  final double strength;

  /// true = 填满父容器（全屏预览页用）；false = 详情页内嵌 220px 小窗。
  final bool expand;

  @override
  State<DepthPreview> createState() => _DepthPreviewState();
}

class _DepthPreviewState extends State<DepthPreview> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _tiltX = 0;
  double _tiltY = 0;
  double _smoothX = 0;
  double _smoothY = 0;

  // 上次真正触发重建的倾斜值：用于变化量门槛（见 _applyTilt）。
  double _lastRenderedX = 0;
  double _lastRenderedY = 0;

  // 陀螺仪瞬态增益：与原生 DepthWallpaperEngine 的 GYRO_GAIN/GYRO_DECAY 同值，
  // 预览甩动手感与壁纸一致。
  static const _gyroGain = 0.9;
  static const _gyroDecay = 0.88;
  double _gyroBoostX = 0;
  double _gyroBoostY = 0;

  /// 位移幅度（逻辑像素）= 强度参数 × 缩放系数，与原生 uStrength 同源。
  double get _amplitudePx => (widget.strength / 0.06) * 24;

  @override
  void initState() {
    super.initState();
    // uiInterval ≈ 与 UI 刷新同步；仅预览页前台时订阅。
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccel);
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen(_onGyro);
  }

  void _onAccel(AccelerometerEvent event) {
    // 与原生 DepthWallpaperEngine 一致的低通滤波（α=0.15）。
    final norm = (event.x * event.x + event.y * event.y + event.z * event.z);
    if (norm < 0.000001) return;
    final len = math.sqrt(norm);
    final tx = (event.x / len).clamp(-1.0, 1.0);
    final ty = (event.y / len).clamp(-1.0, 1.0);
    _smoothX += (tx - _smoothX) * 0.15;
    _smoothY += (ty - _smoothY) * 0.15;
    _applyTilt();
  }

  void _onGyro(GyroscopeEvent event) {
    // 与原生一致：旋转速率 × 时间 = 角度增量，指数衰减只保留瞬态“甩动”。
    _gyroBoostX = (_gyroBoostX * _gyroDecay + event.x * 0.016 * _gyroGain)
        .clamp(-0.5, 0.5);
    _gyroBoostY = (_gyroBoostY * _gyroDecay - event.y * 0.016 * _gyroGain)
        .clamp(-0.5, 0.5);
    _applyTilt();
  }

  void _applyTilt() {
    if (!mounted) return;
    final nx = (_smoothX + _gyroBoostX).clamp(-1.0, 1.0);
    final ny = (_smoothY + _gyroBoostY).clamp(-1.0, 1.0);
    // 变化量门槛：加速度计 + 陀螺仪以 ~60Hz 连发事件，LPF 收敛后数值只在
    // 噪声带内抖动。逐事件 setState 会让预览页常驻满帧重建（功耗无谓翻倍），
    // 低于阈值的更新直接丢弃——视觉上无差别，重建频率随静止自动归零。
    if ((nx - _lastRenderedX).abs() < 0.002 &&
        (ny - _lastRenderedY).abs() < 0.002) {
      return;
    }
    _lastRenderedX = nx;
    _lastRenderedY = ny;
    setState(() {
      _tiltX = nx;
      _tiltY = ny;
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 平移幅度随视差强度参数缩放（0.06 → 24px 基准）：模拟视差观感。
    final dx = -_tiltX * _amplitudePx;
    final dy = -_tiltY * _amplitudePx;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // 过扫描 8% 防止平移露出边缘（与原生 uZoom 同思路）。
        Transform.scale(
          scale: 1.08,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Image.file(
              File(widget.colorPath),
              fit: BoxFit.cover,
              cacheWidth: 720,
              errorBuilder: (_, _, _) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Text(ZunoLocalizations.of(context).colorImageLoadFailed),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.black54,
            child: Text(
              ZunoLocalizations.of(context).depthApproxHint,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ],
    );
    // expand（全屏页）：无边框填满父约束；内嵌模式：12px 圆角 220px 小窗。
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.expand ? 0 : 12),
      child: widget.expand ? content : SizedBox(height: 220, child: content),
    );
  }
}
