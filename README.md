# ZUNO

Android 动态壁纸应用：**视频 / 深度视差 / HTML / 定时** 四种壁纸类型，`com.zuno.wallpaper`，minSdk 24，目标 API 34+。

设计原则：**高性能、低占用、渲染与 UI 严格分离**。Flutter 只做管理端（壁纸库、ZIP 导入、预览、参数配置）；所有壁纸渲染都发生在原生 `WallpaperService` 中，四种类型没有一种经过 Flutter 渲染链路。

云端（壁纸目录、下载分发）不是 App 运行必需：**浏览与下载都不需要登录**，下载只换 5 分钟一次性票据（匿名请求记 `uid=anon`）；账号、上传与删除属于管理端，客户端不提供入口。管理端是独立的 Tauri 桌面应用（[`desktop/`](desktop/README.md)），在本地压缩、直传 WebDAV 并触发同步。壁纸库地址在 App 的「设置 → 壁纸库地址」里配置（存 `zuno_config` 的 `library.base_url`，默认值编译在 `ZunoEndpoint.base`），换地址后会清空并重建目录。契约见 [`docs/backend.md`](docs/backend.md)，实现位于 `backend/`（Workers + D1 + WebDAV）。

---

## 1. 总体架构

```
┌──────────────────────────┐        ┌───────────────────────────────┐
│  主 App（Flutter）        │ Channel│  ZunoWallpaperService（原生）   │
│  · 壁纸库管理（Hive 索引）  │───────▶│  Engine = 生命周期调度器        │
│  · ZIP 导入 + manifest 校验│        │   ├ VideoWallpaperEngine      │
│  · 预览 / 参数配置         │        │   │   ExoPlayer ─▶ Surface    │
│  · 应用壁纸               │        │   ├ DepthWallpaperEngine      │
└──────────────────────────┘        │   │   EGL14 + GLES20 + 传感器   │
        │                           │   ├ HtmlWallpaperEngine       │
        │  WorkManager 周期任务      │   │   离屏 WebView ─▶ 软件画布   │
        ▼                           │   └ （timed 不渲染，见 §2.4）    │
┌──────────────────────────┐        └───────────────────────────────┘
│  TimedWallpaperWorker     │──进程内 ConfigBus──▶ Engine 热切换
│  （≥15 分钟周期调度）       │
└──────────────────────────┘
```

关键决策与"为什么"：

| 决策 | 原因 |
|---|---|
| 视频壁纸走原生 ExoPlayer 直连 Surface（可切硬/软解），不经 Flutter | 解码器直接写 Surface 图形缓冲区（零拷贝）；Flutter Texture 需要跨 GL Context 拷贝，每帧占用 raster 线程 |
| 深度视差走原生 EGL14 + GLES20 单 pass 位移映射 | 一张 GLSL 位移映射就够；Flutter raster 线程对壁纸级常驻渲染是纯开销 |
| HTML 壁纸用**离屏 WebView 软件绘制**进壁纸 Surface | **平台现实**：`WallpaperService.Engine` 的窗口由系统进程创建，App 侧只拿到一个 Surface，**无法在壁纸窗口内嵌入 View 层级**（android-37 的 Engine API 无 `onCreateView`；View 层级嵌入属于 DreamService）。离屏 WebView + `lockCanvas()` 软件画布是该约束下的标准做法 |
| 不把 FlutterEngine 塞进 WallpaperService 常驻 | 四种类型都不需要 Widget 层渲染；`FlutterEngineHolder`（`FlutterEngineGroup` 缓存、长期存活）作为架构扩展位保留给未来的 Widget 层壁纸，默认不创建 |
| timed = WorkManager"元调度器"，非常驻渲染 | 切换只是改 SharedPreferences + 进程内 `ConfigBus` 通知 Engine 热切换；周期最小 15 分钟是平台硬限制，Doze 下会被合并到维护窗口 |

### 生命周期与功耗控制

`Engine.onVisibilityChanged(boolean)` 是功耗枢纽（`ZunoWallpaperService`）：

- `visible == false`：视频 `pause()`；GL 停止帧回调 + 注销传感器监听；WebView `onPause()`（暂停 DOM/JS 定时器）+ 停止绘制循环。
- 省电模式（`PowerManager.isPowerSaveMode()` + `ACTION_POWER_SAVE_MODE_CHANGED` 动态注册）：视频降级为静态首帧；视差强制 15fps；HTML 冻结 CSS 动画（注入 `animation-play-state: paused`）+ 暂停 JS 定时器。
- 性能档位（高/中/低，默认**中**，设置页全局调整）：

| 路径 | 高 | 中 | 低 |
|---|---|---|---|
| 视频 | 正常播放 | 正常播放 | 静态首帧 |
| 深度视差 | 30 fps | 20 fps | 15 fps |
| HTML | 跟随 vsync | ~30 fps | ~15 fps + 冻结 CSS 动画 |

视频解码方式（设置页，`video.decode_mode`）：**自动**优先硬解、完全没有硬解时才用软解；**硬解**只允许硬件解码器；**软解**兼容性最广但耗电/发热明显。硬解失败会记录错误（`video.decode_error`），下次回到 App 时提示切换软解，**不静默降级**。

深度视差倍率（设置页，`depth.strength_scale`，0.4–2.0）：叠加在每个深度包自己的视差强度上，供用户按体感收放整体位移。
---

## 2. ZUNO 壁纸包规范（ZUNO Package v1）

扩展名 `.zip` 或 `.zuno`（本质为 ZIP 容器，store/deflate 均可）。

### 目录布局

```
zuno-root/
├── manifest.json            # 必需，根目录或单一顶层文件夹内
├── thumbnail.png            # 可选，建议 480×800、<200KB
└── content/                 # 必需，所有壁纸素材
```

manifest.json 之外的其他根级文件在导入时被忽略。content/ 必须存在且非空。

### manifest.json 字段

```json
{
  "schemaVersion": 1,
  "id": "com.example.aurora_video",
  "version": "1.0.0",
  "title": "Aurora Loop",
  "author": { "handle": "studio_x" },
  "type": "video",
  "entry": "content/main.mp4",
  "minSdk": 24,
  "checksum": "sha256-...",
  "performanceHint": "medium",
  "config": [
    { "key": "playback_speed", "type": "float", "label": "播放速度",
      "min": 0.5, "max": 2.0, "default": 1.0 }
  ],
  "capabilities": { "network": [], "pointer": false, "sensors": [] }
}
```

| 字段 | 类型 | 必需 | 说明 |
|---|---|---|---|
| schemaVersion | number | 是 | 固定为 1 |
| id | string | 是 | 反向域名或 UUID（`[A-Za-z0-9_.]`）；同 id 导入覆盖旧版本 |
| version | string | 是 | 语义化版本（`1.2.3[-suffix]`） |
| title | string | 是 | 库内显示名 |
| author | object | 否 | `{ id?, handle? }` |
| type | string | 是 | `video` / `html` / `depth` / `timed` |
| entry | string | 是 | 主入口文件相对包根的路径，必须存在 |
| minSdk | number | 否 | 默认 24；高于设备 API 时拒绝导入 |
| checksum | string | 建议 | `sha256-` + hex，覆盖 content/ 下所有文件 |
| performanceHint | string | 否 | `low/medium/high`，默认 medium |
| config | array | 否 | `key`(必需)、`type`(float/int/bool/color)、`label?`、`min/max?`、`default?`、`note?` |
| capabilities | object | 否 | `network: string[]`（v1 实现仍禁网）、`pointer: bool`（HTML 触摸）、`sensors: string[]`（仅 depth 有效） |

### 各 type 的 content/ 结构

- **video**：`content/main.mp4`（H.264/H.265，建议 ≤15s 循环，分辨率 ≤ 屏幕物理分辨率）。
- **depth**：`content/color.jpg`（entry 指向）、`content/depth.png`（灰度、与 color 同尺寸，**必需**，渲染器固定读取该路径）、`content/shader.glsl`（可选，见 §3）。
- **html**：`content/index.html`（entry 指向）+ 包内自包含资源；**禁止外部 CDN**。
- **timed**：`content/schedule.json` + `content/slot_*/`（每个 slot 内有自己的最简 `manifest.json`（schemaVersion/id/type/entry），type 不允许嵌套 timed，slot id 不得与顶层包 id 冲突）。

```json
{
  "rules": [
    { "from": "06:00", "to": "18:00", "wallpaper": "slot_day" },
    { "from": "18:00", "to": "06:00", "wallpaper": "slot_night" }
  ],
  "default": "slot_morning",
  "constraints": { "chargingOnly": false, "minIntervalMinutes": 30 }
}
```

规则匹配：`from < to` 为 `[from, to)`；`from > to` 为跨午夜；`from == to` 视为空窗口（永不匹配）。

### checksum 规范

`content/` 下所有文件按**相对包根的 POSIX 路径**做码元升序排序，依次把 `路径 UTF-8 字节 + 0x0A + 文件字节` 追加进同一 SHA-256 状态，结果表示为 `sha256-<小写 hex>`。`tool/create_sample_packages.dart` 与导入器双侧实现一致（`lib/wallpaper_package/checksum.dart`）。

### 校验顺序（任何一步失败整包拒绝，UI 给出具体原因）

路径遍历检查 → manifest.json 存在性 → 必填字段完整性 → type 合法性 → entry 存在性 → content/ 非空 → minSdk ≤ 设备 API → checksum 比对（若存在）→ timed 子包递归校验。

---

## 3. HTML 壁纸沙箱

- 本地资源经 `WebViewAssetLoader` 以 **`https://appassets.local/`** 提供；`file://` 全禁（`allowFileAccess=false`、`allowFileAccessFromFileURLs=false`、`allowUniversalAccessFromFileURLs=false`、`allowContentAccess=false`）。自定义 `DirectoryPathHandler` 对每个请求做 canonical path 校验防路径逃逸。
- `shouldInterceptRequest` 对一切未被 AssetLoader 命中的请求返回 **403** —— 壁纸默认禁网。`capabilities.network` 需要用户二次确认后放行，**v1 实现选择完全不放行**。
- 导航只允许 `appassets.local` 源内跳转；窗口/弹窗禁用；摄像头/麦克风/定位权限请求一律拒绝。
- JS 桥只有 `@JavascriptInterface setConfig(key, value)` 一个方法（`window.ZunoWallpaper`）；初始配置通过页面加载完成后注入的 `window.__ZUNO_CONFIG__` 全局变量提供。
- **自适应渲染**（功耗优化）：引擎每 3 秒探测一次页面动态性——`document.getAnimations()` 数量 + 近 4 秒内是否有 `requestAnimationFrame`（引擎会在页面加载后给 rAF 打补丁记录时间戳）。探测为静止的页面停止周期重绘，仅在触摸（8 秒宽限期）、参数变化时重绘一帧；动态页面回到档位帧率。**页面可用 `window.__zunoKeepAlive = 1` 强制持续渲染**（用于 setInterval/canvas 自绘等探测不到的动画）。
- WebView 层类型设为 `LAYER_TYPE_NONE`（离屏软件绘制链路下硬件层无收益，仅额外耗显存；规格提示此值需实测，代码中保留为常量便于 A/B）。
- 触摸：`Engine.setTouchEventsEnabled(true)` → `onTouchEvent` 直接 `dispatchTouchEvent` 给离屏 WebView。
- 预览页（`HtmlPreviewActivity`）与壁纸引擎共用同一个 `SandboxedWebViewFactory`，预览即实况。

### depth 自定义着色器契约（content/shader.glsl）

GLSL ES 1.00 片段着色器，替换内置片段源；可用的 uniform（编译器裁剪掉也安全）：

```glsl
precision mediump float;
uniform sampler2D sColor;   // 颜色纹理（unit 0）
uniform sampler2D sDepth;   // 深度纹理（unit 1，.r：0=远 1=近）
uniform vec2  uTilt;        // 低通滤波后的设备倾斜 [-1,1]
uniform float uStrength;    // 视差强度（UV 单位）
uniform float uZoom;        // 过扫描系数（1 + 2*strength）
uniform float uAspect;      // 宽高比
varying vec2  vUV;          // 全屏 UV
```

编译失败时自动回退内置视差着色器并打 logcat。

---

## 4. 构建与运行

```bash
# 环境：Flutter 3.47+（Dart 3.13+），Android SDK 34+，JDK 17
flutter pub get

# 静态检查 + 单元测试（导入/校验全流程测试，无需设备）
flutter analyze
flutter test

# 生成示例包到 samples/（depth / html / timed；视频示例需自备 mp4）
dart run tool/create_sample_packages.dart --video path/to/loop.mp4
# 改图标：替换 assets/icon/app_icon_{background,foreground}_src.png 后依次运行
python -I tool/generate_launcher_icon.py   # 派生 app_icon*.png + 全部 mipmap/自适应层
dart run flutter_launcher_icons            # 生成清单引用的 @mipmap/launcher_icon

# 运行（模拟器或真机）
flutter run
```

### 发布构建（上线）

```bash
# 1. 正式签名：创建 android/key.properties（不入库）：
#    storeFile=/absolute/path/to/release.keystore
#    storePassword=...
#    keyAlias=...
#    keyPassword=...
#    未配置时自动回退 debug 签名（仅本地验证用）。

# 2. Release 构建已默认启用 R8 + 资源收缩（规则见 android/app/proguard-rules.pro；
#    其中 androidx.work.impl.** 整包保留是 AGP 9.1 R8 全模式与 WorkManager 内置
#    Room 反射的兼容性修复——真机 release 崩溃验证后加入，勿删）。
flutter build apk --release                   # 通用 APK（~51MB）
flutter build apk --release --split-per-abi   # 按 ABI 拆分（体积更小）
flutter build appbundle                       # Play Store 上架产物（.aab）

# 3. Release 模式真机验证清单（务必执行：AOT + R8 行为可能与 debug 不同）
#    · 冷启动 App → 壁纸库 UI 正常渲染
#    · 此前应用的动态壁纸仍然工作（home 屏确认）
#    · 导入示例包 → 详情页 → 应用 → 系统选择器确认
#    · logcat 无 FATAL EXCEPTION
```

使用流程：导入 `.zuno` 包 → 详情页调整参数 → **应用此壁纸** → 系统动态壁纸预览页点击"设置壁纸"确认。详情页右上角的**导出/分享**按钮可把已安装包重新打包为 .zuno（流式导出，manifest 的 checksum 依然有效），经系统分享面板发给其他设备后可直接导入。

> 应用路径说明：`WallpaperManager.setWallpaperComponent()` 不在公共 SDK 中（需要系统签名权限 `SET_WALLPAPER_COMPONENT`，已用 android-34 的 android.jar 验证），普通应用设置动态壁纸的唯一途径是 `ACTION_CHANGE_LIVE_WALLPAPER` 系统预览页——ZUNO 由此实现"写入激活配置 → 拉起系统预览"两步应用。timed 包在应用时先解析当前时段的 slot 子包写入激活配置，后续切换由 WorkManager 在进程内热切换，不再走系统流程。

### 项目结构

```
lib/
├── main.dart / app.dart
├── core/zuno_paths.dart
├── models/                  # manifest / 库条目 / 类型 / 调度模型
├── wallpaper_package/       # ← ZIP 解析与 manifest 校验（isolate 安全，纯 Dart）
│   ├── zip_importer.dart    #    导入编排（校验顺序见 §2）
│   ├── manifest_validator.dart
│   ├── zip_exporter.dart    #    流式导出（包 → .zuno，供分享/迁移）
│   ├── path_guard.dart      #    Zip Slip 防御
│   ├── checksum.dart        #    §2 checksum 规范
│   ├── timed_schedule.dart
│   └── validation_failure.dart
├── services/                # Platform Channel 封装 / Hive 库 / 应用器
├── state/library_controller.dart
└── ui/                      # screens / widgets / preview
android/app/src/main/kotlin/com/zuno/wallpaper/
├── MainActivity.kt / ZunoApplication.kt
├── bridge/                  # ZunoBridge（唯一 MethodChannel）、BatteryGuard
├── flutter/FlutterEngineHolder.kt   # 架构扩展位（默认不创建引擎）
└── wallpaper/
    ├── ZunoWallpaperService.kt      # Engine：只做生命周期调度
    ├── ActiveWallpaperStore.kt      # 激活状态唯一事实来源（SharedPreferences）
    ├── ConfigBus.kt                 # 进程内热切换事件总线
    ├── PerformanceTier.kt
    ├── engine/                      # video / depth / html 三条渲染路径 + 委托接口
    ├── gl/                          # GlRenderThread（EGL14）、ParallaxRenderer、ShaderUtil
    ├── html/                        # SandboxedWebViewFactory、DirectoryPathHandler、
    │                                # WallpaperJsBridge、MimeTypes、HtmlPreviewActivity
    └── timed/                       # TimedScheduleResolver、TimedWallpaperWorker(+Scheduler)
tool/create_sample_packages.dart     # 示例包生成器
test/zip_importer_test.dart          # 导入/校验单元测试
backend/                             # Workers + D1 + WebDAV 云端（契约见 docs/backend.md）
│ └── src/admin-delete.ts             #  管理端删除：D1 记录（文件由管理端直连 WebDAV 删）
desktop/                             # Tauri 2 壁纸管理端（详见 desktop/README.md）
  ├── src/                           #  TypeScript 前端：云端 / 本地 / 设置
  └── src-tauri/src/                 #  Rust：校验、checksum、压缩、上传、预览、删除
```

---

## 5. 已知平台限制

1. **HTML 壁纸的渲染路径**：壁纸窗口由系统进程管理、无法嵌入 View 层级（§1），因此 HTML 壁纸每帧走 `WebView.draw()` 软件绘制。成本与页面复杂度线性相关——帧率档位就是功耗保险丝；简单 CSS/Canvas 页面在 30fps 下表现良好，重型 WebGL 页面不适合做壁纸。
2. **HTML 禁网是硬性的**：`capabilities.network` 声明在 v1 中被记录但**不放行**（避免"壁纸偷跑流量"风险）。需要用户二次确认的放行机制留作后续版本。
3. **WorkManager 最小周期 15 分钟**：timed 壁纸的分钟级精度在 Doze 模式下不可保证（系统会合并到维护窗口）。激活 timed 包时还会在下一个规则边界排一次性任务（`scheduleNext`，非精确闹钟，Doze 同样会推迟），15 分钟周期任务保留为兜底。`constraints.minIntervalMinutes` 做切换节流；加入电池优化白名单可显著降低延迟（设置页有引导）。
4. **动态壁纸必须经系统预览/选择器确认**，无法静默设置。且存在 ROM 差异：标准 `ACTION_CHANGE_LIVE_WALLPAPER`（带确认的系统预览页）在部分 ROM（实测 Xiaomi HyperOS）上没有处理器，ZunoBridge 会自动回退到 `ACTION_LIVE_WALLPAPER_CHOOSER`（系统选择器的“动态壁纸”列表，实测可用），两级都失败时返回 false 由 UI 提示。
5. **同进程约束**：WallpaperService 与主 App 同进程（未声明 `android:process`），`ConfigBus` 热切换依赖这一点。若未来拆分进程，需要改用广播/Messenger。
6. **`pauseTimers()` 未使用**：它是 WebView 进程级开关，会连 App 内 HTML 预览 Activity 一起冻结；改用 per-view `onPause()/onResume()`。
7. **深度视差仅用加速度计+陀螺仪**：`capabilities.sensors` 在导入时记录；运行时设备无对应传感器则渲染为静态图（有 logcat 提示）。
8. **深度视差静止降帧**：倾斜低通滤波的变化量在 2 秒内低于阈值（设备平放）时，帧率自动压到 15fps；一旦倾斜变化立即回到档位帧率。省电模式的 15fps 上限与之叠加取更小值。
9. **导入缩略图**：包自带 `thumbnail.png` 时优先使用；没有时导入器自动生成——video 取首帧关键帧、depth 缩放颜色图、html 用沙箱 WebView 离屏真实渲染页面后截图（480×800、JPEG 质量 82，与壁纸渲染同一套实现），timed 父包显示占位图标。
10. **SAF 文件选择器与自定义扩展名**：`FileType.custom` + 自定义扩展名（.zuno）会被部分 ROM 的 documentsui 禁用条目（无法按 MIME 匹配），因此导入使用 `FileType.any`，由导入器的完整校验链拒绝非法文件。
11. **备份策略**：`allowBackup=false`——壁纸包是可再导入的便携文件（详情页导出/分享即迁移手段），云端备份 72MB 级视频会超出 Play 25MB 配额且无意义；用户参数与索引随应用数据生命周期。
12. **设备/ROM 差异**：`WebView.setLayerType(LAYER_TYPE_NONE)` 的取舍（§3）、省电模式广播的送达时机、部分 OEM 对 WorkManager 的加急限制，均需在目标机型上实测。
13. **模拟器（MuMu 等）怪癖**：`install -r` 更新时其修改版 WallpaperManagerService 对 PACKAGE_REMOVED/ADDED 广播对存在竞态，偶发把动态壁纸判为 "uninstalled, removing" 并回退系统默认（真机 AOSP 无此问题，动态壁纸跨更新保持是标准行为）——模拟器上重新应用一次即可。
14. **`gradlew lint` 环境限制**：pub 缓存与工程跨盘符（C:/D:）时插件 lint 模型任务解析失败，无法在本布局下运行 Android Lint；Kotlin 层质量由"编译零警告 + R8 通过 + 真机运行验证"保障。

## 6. 验证状态（上线审计后）

以下门禁全部在本仓库实测通过：

- `flutter analyze`：No issues found。
- `flutter test`：37/37 通过——
  - ZIP 导入全流程、Zip Slip 拒绝、manifest id 路径遍历拒绝（`.`/`..`）、type/entry/minSdk/content 校验、checksum 比对、timed 递归校验（slot 缺失 / id 冲突 / 嵌套 timed / 空 content）、畸形 capabilities 不崩溃、跨午夜时段解析；
  - samples/ 三个示例包的端到端导入回归；
  - ConfigEditor / PackageCard / TypeBadge 的 Widget 测试。
- 构建产物：
  - `flutter build apk --debug`：成功；
  - `flutter build apk --release`：成功（**R8 + 资源收缩开启**，50.9MB，含 WorkManager Room 反射兼容 keep 规则——真机崩溃验证后加入，见 proguard-rules.pro 注释）；
  - `flutter build appbundle`：成功（Play Store 上架产物 .aab）。
- 设备端全类型验证（MuMu 模拟器 / Android 16 镜像，Release 模式，logcat 零 FATAL）。
- 本轮新增验证：设置页齿轮图标与深色/浅色下的分段控件截图确认；视频解码方式（自动/硬解/软解）与深度倍率写入 `zuno_config` 后重启保持；ExoPlayer 壁纸引擎在 `flutter build apk --release`（R8 + 资源收缩）下编译通过。系统动态壁纸预览页之后的桌面色帧本轮未截图确认（模拟器整屏截图管线卡死），需真机复验。第十轮后新增：`onSurfaceRedrawNeeded` 转发（HTML 静态页亮屏重绘）、三类型 `onComputeColors`（Material You 取色，"Cannot extract colors" 告警归零）、`allowBackup=false` 备份策略、HTML 引擎档位字段缓存（消除每帧 store 读取）。
- **实测 CPU 占用**（MuMu x86_64，`top -b -n 3` 采样，540×960 网格页前台）：视频壁纸（H.264 硬解播放中）**2.0–3.7%**；HTML 壁纸（动画星空页 30fps 软件绘制）**7.6–9.0%**；深度壁纸（GL 20fps + 虚拟传感器输入）**8.5–11.5%**。视频路径的硬解直连设计得到数据验证；模拟器 gfxstream 图形后端对 GL/WebView 路径有额外开销，真机数字预期更低。
  - **HTML**：导入（沙箱 WebView 离屏截图缩略图）→ 应用 → 主屏星空实时渲染，WebView 沙箱进程存活；
  - **深度**：导入 → 应用 → **GL 渐变与月亮正确渲染**（发现并修复“不可见期创建的线程永不恢复渲染”缺陷，见 DepthWallpaperEngine.onVisibilityChanged）；
  - **视频**：导入（首帧缩略图）→ 应用 → 路径解析缺陷已修复；AV1 编码在模拟器硬解上不受支持 → 已新增**导入期编码探测告警**（H.264/H.265 规格列表外弹出提醒，真机硬件解码不受影响）；壁纸引擎已从 `MediaPlayer` 换成 ExoPlayer（`media3` 1.9.2，与预览同版本），设置页可切自动/硬解/软解；
  - **timed**：导入 → 调度窗口/当前时段解析正确 → slot 子壁纸渲染；WorkManager worker 通过 `cmd jobscheduler run` 强制执行无崩溃（实际切换粒度 ≥15 分钟为平台限制）；边界一次性任务与 `APPEND_OR_REPLACE` 续排逻辑经代码审查（最小延迟 5 秒防空转），长时观察仍需真机；
  - 导出/分享：打包 → FileProvider → 系统分享面板拉起成功（测试镜像无分享目标属环境现象）；
  - 审计中发现并回写代码：ROM 三级回退链（§5.4）、`FileType.any`（§5.10）、R8 WorkManager 兼容规则（§4）。
- 上线前仍需人工完成：配置正式签名密钥（android/key.properties）、Play Console 元数据与隐私声明（本应用无网络权限、零数据采集）、真机硬件上的深度视差传感器位移与 timed 长时观察。

---

## 许可证

[MIT](LICENSE)。示例壁纸包（`samples/`）仅用于测试与格式演示。

