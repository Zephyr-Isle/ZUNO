// 示例 .zuno 包生成器。
//
// 用法（在项目根目录）：
//   dart run tool/create_sample_packages.dart            # 生成 depth / html / timed 示例到 samples/
//   dart run tool/create_sample_packages.dart --video path/to/loop.mp4   # 附带生成视频示例
//
// 生成的包完全符合 ZUNO Package v1 规格（含按规范计算的 checksum），
// 可直接在 ZUNO 中导入。视频示例需要自备 ≤15s 的 H.264/H.265 mp4（工具不伪造视频字节）。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;

void main(List<String> args) {
  final outDir = Directory('samples');
  outDir.createSync(recursive: true);

  _buildDepthPackage(outDir);
  _buildHtmlPackage(outDir);
  final minInterval = int.tryParse(_argValue(args, '--minInterval') ?? '') ?? 30;
  _buildTimedPackage(outDir, minIntervalMinutes: minInterval);

  final videoArg = _argValue(args, '--video');
  if (videoArg != null) {
    // --id / --out 支持生成多个互不覆盖的视频示例包（如 AV1 降级测试包）。
    final id = _argValue(args, '--id');
    final outName = _argValue(args, '--out') ?? 'sample_video.zuno';
    _buildVideoPackage(
      outDir,
      videoArg,
      outName,
      id: id,
      title: id == null ? null : 'Sample Video ($id)',
    );
  } else {
    stdout.writeln('提示：未提供 --video <mp4>，跳过视频示例（工具不会伪造视频文件）。');
  }

  stdout.writeln('\n完成。示例包位于 ${outDir.path}/，可直接在 ZUNO 中导入。');
}

String? _argValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == name && i + 1 < args.length) return args[i + 1];
  }
  return null;
}

// ---------------------------------------------------------------- depth 包

void _buildDepthPackage(Directory outDir) {
  const w = 320, h = 568; // 小尺寸示例：导入快；真机建议 720×1280 以上
  final color = _Uint8ListBuilder(w * h * 3);
  final depth = _Uint8ListBuilder(w * h);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      // 颜色图：夜空渐变 + 一轮“月亮”。
      final t = y / h;
      var r = (40 + 160 * t).toInt();
      var g = (60 + 120 * t).toInt();
      var b = (140 + 60 * (1 - t)).toInt();
      final moonDx = x - w * 0.7, moonDy = y - h * 0.25;
      final moonDist = math.sqrt(moonDx * moonDx + moonDy * moonDy);
      if (moonDist < w * 0.09) {
        r = 245;
        g = 240;
        b = 210;
      }
      // 深度图：月亮最近（1.0）、天空最远（0.0）、越往下越近。
      var d = 0.25 + 0.75 * t * t;
      if (moonDist < w * 0.09) d = 1.0;
      color.set(i * 3, r);
      color.set(i * 3 + 1, g);
      color.set(i * 3 + 2, b);
      depth.set(i, (d * 255).toInt());
    }
  }

  final files = <String, List<int>>{
    'manifest.json': _json({
      'schemaVersion': 1,
      'id': 'com.zuno.sample.depth',
      'version': '1.0.0',
      'title': 'Sample Depth Parallax',
      'author': {'handle': 'zuno_samples'},
      'type': 'depth',
      'entry': 'content/color.png',
      'minSdk': 24,
      'performanceHint': 'medium',
      'config': [
        {
          'key': 'parallax_strength',
          'type': 'float',
          'label': '视差强度',
          'min': 0.0,
          'max': 0.15,
          'default': 0.06,
          'note': '位移幅度（UV 单位）',
        },
      ],
      'capabilities': {
        'network': [],
        'pointer': false,
        'sensors': ['gyroscope', 'accelerometer'],
      },
    }),
    'content/color.png': _encodePng(w, h, color.bytes, hasColor: true),
    'content/depth.png': _encodePng(w, h, depth.bytes, hasColor: false),
  };
  files['manifest.json'] = _withChecksum(files);

  _writeZip(outDir, 'sample_depth.zuno', files);
  stdout.writeln('✓ sample_depth.zuno');
}

// ---------------------------------------------------------------- html 包

void _buildHtmlPackage(Directory outDir) {
  final html = '''<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  html, body { margin: 0; height: 100%; background: #0b0b18; overflow: hidden; }
  .star { position: absolute; width: 2px; height: 2px; background: #fff;
          border-radius: 50%; animation: twinkle 3s infinite ease-in-out; }
  @keyframes twinkle { 0%,100% { opacity: .2 } 50% { opacity: 1 } }
  .orb { position: absolute; left: 30%; top: 20%; width: 40vmin; height: 40vmin;
         border-radius: 50%;
         background: radial-gradient(circle at 35% 35%, #8b80f9, #2a2360 70%);
         box-shadow: 0 0 12vmin 2vmin rgba(139,128,249,.35);
         animation: drift 8s infinite ease-in-out; }
  @keyframes drift { 0%,100% { transform: translateY(0) } 50% { transform: translateY(3vmin) } }
  .hint { position: absolute; bottom: 4vmin; left: 0; right: 0; text-align: center;
          color: rgba(255,255,255,.35); font: 12px sans-serif; }
</style>
</head>
<body>
  <div class="orb"></div>
  <div class="hint">ZUNO HTML sandbox · appassets.local · 无网络</div>
  <script>
    // 星空：纯包内资源；星星数量来自 manifest.config（原生启动时注入 __ZUNO_CONFIG__）。
    var count = 120;
    try {
      count = Math.round((window.__ZUNO_CONFIG__ && window.__ZUNO_CONFIG__.star_density) || 120);
    } catch (e) {}
    for (var i = 0; i < count; i++) {
      var s = document.createElement('div');
      s.className = 'star';
      s.style.left = Math.random() * 100 + '%';
      s.style.top = Math.random() * 100 + '%';
      s.style.animationDelay = (Math.random() * 3) + 's';
      document.body.appendChild(s);
    }
    // 示例：通过唯一的桥方法回写参数（原生会持久化并在下轮可见时重新注入）。
    if (window.ZunoWallpaper) {
      ZunoWallpaper.setConfig('star_density', String(count));
    }
  </script>
</body>
</html>
''';

  final files = <String, List<int>>{
    'manifest.json': _json({
      'schemaVersion': 1,
      'id': 'com.zuno.sample.html',
      'version': '1.0.0',
      'title': 'Sample HTML Starfield',
      'author': {'handle': 'zuno_samples'},
      'type': 'html',
      'entry': 'content/index.html',
      'minSdk': 24,
      'performanceHint': 'medium',
      'config': [
        {
          'key': 'star_density',
          'type': 'int',
          'label': '星星数量',
          'min': 20,
          'max': 400,
          'default': 120,
        },
      ],
      'capabilities': {'network': [], 'pointer': true, 'sensors': []},
    }),
    'content/index.html': utf8.encode(html),
  };
  files['manifest.json'] = _withChecksum(files);

  _writeZip(outDir, 'sample_html.zuno', files);
  stdout.writeln('✓ sample_html.zuno');
}

// ---------------------------------------------------------------- timed 包

void _buildTimedPackage(Directory outDir, {int minIntervalMinutes = 30}) {
  const w = 160, h = 284;

  List<int> slotColor(int hueShift) {
    final buf = _Uint8ListBuilder(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        final t = y / h;
        buf.set(i * 3, (hueShift + 120 * t).toInt().clamp(0, 255));
        buf.set(i * 3 + 1, (80 + 100 * (1 - t)).toInt());
        buf.set(i * 3 + 2, (160 - hueShift ~/ 3).toInt());
      }
    }
    return _encodePng(w, h, buf.bytes, hasColor: true);
  }

  final depth = _Uint8ListBuilder(w * h);
  for (var i = 0; i < w * h; i++) {
    depth.set(i, (0.3 * 255).toInt());
  }
  final depthPng = _encodePng(w, h, depth.bytes, hasColor: false);

  List<int> slotManifest(String id) => _json({
        'schemaVersion': 1,
        'id': id,
        'type': 'depth',
        'entry': 'content/color.png',
      });

  final files = <String, List<int>>{
    'manifest.json': _json({
      'schemaVersion': 1,
      'id': 'com.zuno.sample.timed',
      'version': '1.0.0',
      'title': 'Sample Timed Day/Night',
      'author': {'handle': 'zuno_samples'},
      'type': 'timed',
      'entry': 'content/schedule.json',
      'minSdk': 24,
    }),
    'content/schedule.json': _json({
      'rules': [
        {'from': '06:00', 'to': '18:00', 'wallpaper': 'slot_day'},
        {'from': '18:00', 'to': '06:00', 'wallpaper': 'slot_night'},
      ],
      'default': 'slot_night',
      'constraints': {'chargingOnly': false, 'minIntervalMinutes': minIntervalMinutes},
    }),
    'content/slot_day/manifest.json': slotManifest('com.zuno.sample.timed.slot_day'),
    'content/slot_day/content/color.png': slotColor(30),
    'content/slot_day/content/depth.png': depthPng,
    'content/slot_night/manifest.json': slotManifest('com.zuno.sample.timed.slot_night'),
    'content/slot_night/content/color.png': slotColor(180),
    'content/slot_night/content/depth.png': depthPng,
  };
  files['manifest.json'] = _withChecksum(files);

  _writeZip(outDir, 'sample_timed.zuno', files);
  stdout.writeln('✓ sample_timed.zuno');
}

// ---------------------------------------------------------------- video 包

void _buildVideoPackage(Directory outDir, String videoPath, String outName,
    {String? id, String? title}) {
  final src = File(videoPath);
  if (!src.existsSync()) {
    stderr.writeln('错误：--video 指定的文件不存在: $videoPath');
    exitCode = 2;
    return;
  }
  final packageId = id ?? 'com.zuno.sample.video';
  final files = <String, List<int>>{
    'manifest.json': _json({
      'schemaVersion': 1,
      'id': packageId,
      'version': '1.0.0',
      'title': title ?? 'Sample Video Loop',
      'author': {'handle': 'zuno_samples'},
      'type': 'video',
      'entry': 'content/main.mp4',
      'minSdk': 24,
      'performanceHint': 'high',
      'config': [
        {
          'key': 'playback_speed',
          'type': 'float',
          'label': '播放速度',
          'min': 0.5,
          'max': 2.0,
          'default': 1.0,
        },
        {
          'key': 'volume',
          'type': 'float',
          'label': '音量',
          'min': 0.0,
          'max': 1.0,
          'default': 0.0,
          'note': '壁纸默认静音',
        },
      ],
      'capabilities': {'network': [], 'pointer': false, 'sensors': []},
    }),
    'content/main.mp4': src.readAsBytesSync(),
  };
  files['manifest.json'] = _withChecksum(files);
  _writeZip(outDir, outName, files);
  stdout.writeln('✓ $outName');
}

// ---------------------------------------------------------------- 通用工具

/// 按 README 规定的规范计算 checksum 并写回 manifest：
/// 对 content/ 下所有文件按相对路径排序后，依次累加 `路径 UTF-8 字节 + 0x0A + 文件字节`。
List<int> _withChecksum(Map<String, List<int>> files) {
  final relPaths = files.keys
      .where((p) => p != 'manifest.json' && p.startsWith('content/'))
      .toList()
    ..sort((a, b) => a.compareTo(b));
  final payload = BytesBuilder();
  for (final p in relPaths) {
    payload.add(utf8.encode(p));
    payload.add([0x0A]);
    payload.add(files[p]!);
  }
  final hex = crypto.sha256.convert(payload.toBytes()).toString();
  final manifest = jsonDecode(utf8.decode(files['manifest.json']!)) as Map<String, dynamic>;
  manifest['checksum'] = 'sha256-$hex';
  return _json(manifest);
}

List<int> _json(Object o) =>
    utf8.encode(const JsonEncoder.withIndent('  ').convert(o));

void _writeZip(Directory outDir, String name, Map<String, List<int>> files) {
  final archive = Archive();
  // 排序写入，保证 zip 内容顺序稳定（便于复现 checksum 之外的调试比对）。
  final names = files.keys.toList()..sort();
  for (final name in names) {
    final data = files[name]!;
    // 大体积二进制（视频）用 STORE：MP4 本身已压缩，deflate 纯浪费几十秒。
    if (data.length > 8 * 1024 * 1024) {
      archive.addFile(ArchiveFile.noCompress(name, data.length, data));
    } else {
      archive.addFile(ArchiveFile(name, data.length, data));
    }
  }
  final bytes = ZipEncoder().encode(archive)!;
  File('${outDir.path}/$name').writeAsBytesSync(bytes);
}

class _Uint8ListBuilder {
  _Uint8ListBuilder(int length) : bytes = Uint8List(length);

  final Uint8List bytes;

  void set(int index, int value) {
    bytes[index] = value.clamp(0, 255);
  }
}

/// 手写 PNG 编码器（filter 0 扫描线 + zlib 压缩）：
/// 示例生成器因此不引入额外图像依赖。RGB 或 8-bit 灰度。
List<int> _encodePng(int w, int h, Uint8List pixels, {required bool hasColor}) {
  final bytesPerPx = hasColor ? 3 : 1;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter type 0（None）
    final start = y * w * bytesPerPx;
    raw.add(pixels.sublist(start, start + w * bytesPerPx));
  }
  final idat = ZLibEncoder().encode(raw.toBytes());

  final crcTable = _buildCrcTable();
  int crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG 签名

  void chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final typeBytes = utf8.encode(type);
    out.add(typeBytes);
    out.add(data);
    final crc = ByteData(4)..setUint32(0, crc32([...typeBytes, ...data]));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, hasColor ? 2 : 0) // 2=RGB, 0=grayscale
    ..setUint8(10, 0) // deflate
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', idat);
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) == 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c & 0xFFFFFFFF;
  }
  return table;
}
