/// ZUNO 壁纸包的四种类型（ZUNO Package v1 规格）。
///
/// timed 不是渲染类型，而是调度层：它的 content/ 里是若干独立子壁纸（slot）
/// 和一份 schedule.json，由原生 WorkManager 周期任务切换“当前激活壁纸”。
enum WallpaperType {
  video('video'),
  html('html'),
  depth('depth'),
  timed('timed');

  const WallpaperType(this.wire);

  final String wire;

  static WallpaperType? tryParse(String? raw) {
    for (final t in WallpaperType.values) {
      if (t.wire == raw) return t;
    }
    return null;
  }
}
