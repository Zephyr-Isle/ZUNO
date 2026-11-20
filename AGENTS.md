# AGENTS.md

ZUNO is an Android-only dynamic wallpaper app (video / depth / HTML / timed). Flutter is the **management UI only** — every wallpaper is rendered by native Android code. `README.md` is the authoritative spec; read §1–§3 before changing rendering, the `.zuno` package format, or the HTML sandbox, and §5 for known platform limits.

## Commands (run from the repo root)

- `flutter pub get` — requires Flutter 3.47+ / Dart 3.13+.
- `flutter analyze` — does not check Kotlin; `analysis_options.yaml` excludes `android/**`.
- `flutter test` — all tests are device-free; no emulator needed. `test/sample_packages_test.dart` uses the relative `samples/` path, so run from the root.
- Single file: `flutter test test/zip_importer_test.dart`
- Single case: `flutter test test/zip_importer_test.dart --plain-name "拒绝：checksum 不匹配"`
- Regenerate sample fixtures: `dart run tool/create_sample_packages.dart` (add `--video path/to/loop.mp4`; `--id` / `--out` create extra video samples).
- Release: `flutter build apk --release`, `flutter build apk --release --split-per-abi`, or `flutter build appbundle`.
- There is no CI or pre-commit config; `flutter analyze && flutter test` is the full gate.
- 后端（独立 npm 工程，不参与 Flutter 构建）：`cd backend && npm install && npm run typecheck`；本地联调 `npm run dev` 配 `tool/stub-webdav.mjs`。

## Architecture

- Flutter must not render wallpapers. Native renderers live in `android/app/src/main/kotlin/com/zuno/wallpaper/wallpaper/{engine,gl,html,timed}/`; `ZunoWallpaperService` only dispatches lifecycle.
- 视频壁纸由 `VideoWallpaperEngine` 的 ExoPlayer 直连 Surface（`androidx.media3:media3-exoplayer` 1.9.2，与 `video_player_android` 同版本，勿单独升级以免重复类）。解码方式存 `video.decode_mode`（auto/hardware/software）：auto 仅在没有硬解时回退软解；硬解失败写 `video.decode_error`，`MainShellScreen` 回前台时提示切换软解，**不得静默降级**。
- ZUNO owns exactly one Dart↔native channel: `zuno/native`. Add methods in both `lib/services/platform_bridge.dart` and `android/.../bridge/ZunoBridge.kt`.
- `ActiveWallpaperStore` (native SharedPreferences file `zuno_config`) is the source of truth for the active wallpaper, config, performance tier, app appearance (`app.theme_mode`), and the wallpaper-library base URL (`library.base_url`). Do not add `shared_preferences`; Dart writes must go through the channel.
- HTML preview, wallpaper, and thumbnail rendering intentionally share `SandboxedWebViewFactory`; keep them on the same path so the preview matches the wallpaper.
- `timed` packages never render themselves: they resolve a slot and WorkManager (`TimedWallpaperWorker`) hot-swaps through the in-process `ConfigBus`. The service must stay in the same process (no `android:process`). Slot switches must reuse `timed.parent_config`, or the user's settings are lost. 除 15 分钟周期任务外，`TimedWallpaperScheduler.scheduleNext()` 在下一个规则边界排一次性任务（`nextTransitionDelayMillis` 最少 5 秒防空转），周期任务保留为 Doze 兜底。续排策略分两条（边界任务带 `KEY_BOUNDARY` 输入标记）：边界 worker 必须用 `APPEND_OR_REPLACE`（`REPLACE` 会取消正在运行的自己）；周期兜底 worker 必须用 `REPLACE`——两种都用 `APPEND_OR_REPLACE` 会让每条边界任务再各自续排后继，任务链按代指数增长（约 2^小时），一天就能堆出数十万条空转任务。
- `lib/wallpaper_package/` is deliberately pure Dart (`dart:*`, archive, crypto) so it can run in `compute`. Keep Flutter imports out of it.

## 云端后端（`backend/`）

- `docs/backend.md` 是契约（Workers + D1 + WebDAV，**不使用 R2**），`backend/` 是实现；改接口/表结构先改文档再改 `schema.sql` 与 `src/`。
- Worker 对 WebDAV **只读**：上传由管理端直连，不要添加上传接口或任何 WebDAV 写入调用。
- 下载必须流式透传 `upstream.body`；`arrayBuffer()` 整文件读会撞 128MB 内存上限。**Workers 的 fetch 子请求会剥掉 `Range` 和 `Accept-Encoding`**，上游永远回整文件 200，206/断点续传是做不到的——不要按 206 验收，也不要向客户端承诺续传（见 `docs/backend.md` §5）。
- `POST /api/admin/sync` 按包分页：管理端上传后必须用 `?id=<包 id>` 只同步这一个包；整目录扫描走 `?offset=&limit=` 循环，直到 `nextOffset` 为 null。免费版单请求 50 次子请求，一次扫全量会在中途被截断，表现为“包在 WebDAV 上、App 目录里没有”。
- `propfind()` 必须过滤掉 MULTISTATUS 里被列目录自身：不过滤会让 sync 把 `packages/` 当成一个包、把包目录当成版本目录多扫一层，几十次子请求在扫到第一个真实包前就耗光。
- 每个 `<id>/<version>/` 目录都要有 `manifest.json` 旁车（管理端上传时写入）；没有旁车的包只能靠整文件下载抠 ZIP，>16MB 直接跳过。
- 免费版单请求 10ms CPU，所以 PBKDF2 默认 10000 次；上 Workers Paid 后再调 `PBKDF2_ITERATIONS`。
- `webdav_path` / `cover_path` 只存 D1，不下发给客户端；客户端只拿壁纸 id + 票据。
- Secret（`WEBDAV_USER` / `WEBDAV_PASS` / `TICKET_SECRET` / `ADMIN_SECRET`）只走 `wrangler secret` 或本地 `.dev.vars`，不提交、不进聊天。

## Package format (`.zuno`)

- `.zuno` is a ZIP; the full spec is README §2. The validation order in `lib/wallpaper_package/zip_importer.dart` is fixed (path guard → manifest → fields → type → entry → content → minSdk → checksum → timed recursion). Tests assert each failure; don't reorder or bypass.
- 预览图（包内 `thumbnail.png` 与云端 `covers/<id>.png`）统一是 **480×800 竖屏截图**：只截壁纸画面本身，不加标题、副标题、边框、模糊背景之类的装饰。HTML 包用无头 Edge 以 960×1600 打开 `content/index.html` 截图再缩到 480×800，视频包取一帧裁成竖屏。`thumbnail.png` 不参与 checksum，但换图后要重打包上传，并同步替换 `covers/<id>.png`。
- The checksum rule is implemented twice: `lib/wallpaper_package/checksum.dart` and `_withChecksum` in `tool/create_sample_packages.dart`. Change both together, update README §2, then regenerate `samples/`.
- `samples/*.zuno` are fixtures for `test/sample_packages_test.dart`. That test silently skips when the files are missing, so a green run does not prove they exist or are current.
- The picker intentionally uses `FileType.any`; custom `.zuno` extensions are disabled by some ROM document pickers.

## Android / release

- `applicationId` and namespace are `com.zuno.wallpaper`, `minSdk 24`, `compileSdk 37` (pinned), JDK 17, Gradle 9.3.1.
- Edit `android/app/src/main/kotlin/com/zuno/wallpaper/MainActivity.kt`.
- Release builds enable R8 + resource shrinking. Do not remove the `androidx.work.impl.**` keep rule in `android/app/proguard-rules.pro`; without it release crashes during WorkManager init.
- `android/key.properties` enables real signing; when absent, release silently falls back to debug signing.
- `gradlew lint` does not work in this layout (pub cache on C:, project on D:). Verify Kotlin by compiling, building release with R8, and a device smoke test.
- `kotlin.incremental=false` in `gradle.properties` is intentional (Windows incremental-cache lock failures).
- Icons are derived from two design layers, `assets/icon/app_icon_background_src.png` (2000×2000 rounded tile) and `app_icon_foreground_src.png` (1748×1648 transparent glass Z with its shadow, pasted at `(141, 127)`). `python -I tool/generate_launcher_icon.py` composites them and writes `app_icon.png` + `app_icon_foreground.png` + every `ic_launcher*` mipmap/adaptive layer; `dart run flutter_launcher_icons` then produces `@mipmap/launcher_icon` (the manifest's `android:icon`). Changing the artwork means replacing those two layers and running **both** commands in that order. The adaptive foreground is deliberately the flat background colour plus only the Z at 82% — never the composed tile, whose 1px edge highlight survives a rectangular crop and leaves white arcs at the rounded corners. `adaptive_icon_foreground_inset: 0` in pubspec is required because the generator already applies the 72dp safe-zone padding.

## Platform constraints (do not try to "fix" these)

- HTML wallpapers are hard-offline: `appassets.local` only, unmatched requests get 403, and `capabilities.network` is recorded but never granted.
- A live wallpaper cannot be set silently: write the active state, then open the system preview (`ACTION_CHANGE_LIVE_WALLPAPER`, with chooser fallbacks). `setWallpaperComponent()` requires system permissions and is not in the public SDK.
- WorkManager's minimum periodic interval is 15 minutes, and Doze can delay timed switches further. Do not promise minute-level accuracy.
- `WebView.pauseTimers()` is intentionally unused (it also freezes the in-app HTML preview); use per-view `pause()` / `resume()`.
- Emulators (MuMu) may drop the active live wallpaper on reinstall; re-applying is expected, not a bug.

## Conventions

- Comments, UI strings, test names, and docs are Chinese. Match this.
- All in-app icons come from `hugeicons` (stroke-rounded) via the `AppIconData`/`AppIcons`/`appIcon()` helpers in `lib/ui/widgets/app_icons.dart` — never `Icon(Icons.*)`. HugeIcons data is `List<List<dynamic>>` SVG paths, not `IconData`; `appIcon()` with no color/size inherits the parent `IconTheme`. Bottom `GlassTab`s must use the **same** glyph for selected/unselected (only color + label weight differ) — two glyphs make the icon appear to morph on switch. Pick semantically fitting glyphs (e.g. grid for 壁纸库, gear `Settings02` for settings, iOS-style share03 for share); temp gallery pages used for glyph selection must be deleted afterwards.
- The `cupertino_icons` dependency in pubspec.yaml is **required by liquid_glass_widgets internals** (39 files use `CupertinoIcons.*` default glyphs — GlassToast type icons, GlassListTile chevron, GlassStepper, swipe actions…), but the package's own pubspec fails to declare it. Removing it makes every package-default icon render as a `⍰` placeholder.
- The app imitates Apple's Controls Parity style in both light and dark themes, with no gradient/starfield backdrop. Use `Theme.of(context).scaffoldBackgroundColor` and `zunoStatusBarStyle(context)` on every `GlassScaffold` — never hardcode `zunoPageBackground` (#F2F1F7) or a dark status bar. `ThemeController` (pref `app.theme_mode`; system/light/dark, default system) drives `MaterialApp.themeMode`; the settings 外观 section switches it. Glass keeps `brightnessResolver: Theme.maybeBrightnessOf`, so glass follows the app theme even when it differs from the OS.
- `zunoAccent` (#007AFF) is the only accent: import/apply CTA, `ColorScheme.primary`, sliders, active badges and tab selection all use it. Do not add a second accent; type-badge and status colors are semantic exceptions.
- `MainShellScreen` owns the single `lgw.GlassScaffold` + `lgw.GlassAppBar` + `GlassTabBar.bottom` for the two main tabs (我的壁纸 / 壁纸库; the 我的 account tab is intentionally unmounted, its files are kept for later); pushed screens (detail/settings/about) have their own `GlassScaffold`.
- Tab pages are mounted **only when selected** (`_selectedIndex == 0 ? HomeScreen : …`), never an `IndexedStack`: surfaces that join the page-level glass layer (`GlassContainer.card`, `GlassButton` without `useOwnLayer`) get painted by that layer regardless of IndexedStack's paint-skip, so a kept-alive offstage tab bleeds its glass cards/buttons through the active one (幽灵穿透，滚动时看着像部分组件变形). One-shot startup prompts (e.g. the 设为动态壁纸 dialog) therefore live in the shell's `initState`, not in a tab page — a tab page re-runs them on every switch.
- `GlassScaffold` uses `extendBody: true` + the package's soft edge fade (with `extendBody: false` the fade is disabled and scroll content is hard-cut mid-line under the bars). Each page's scroll view pads its content past the chrome: top `MediaQuery.padding.top + 44 + gap`, bottom `102 + MediaQuery.padding.bottom` for the main shell (barHeight 66 + verticalPadding 18×2) and its floating CTA. Pages with a `bottomBar` (settings save row 70, detail CTA 110, remote download 76) must add that height to the bottom padding too, or the last list rows stay trapped behind the fixed buttons.
- `GlassScaffold` is Cupertino-based: wrap Material body widgets in `Material(type: MaterialType.transparency)` or they throw "No Material widget found".
- Never put a glass control inside `GlassSurface`/`GlassContainer` (double refraction). Put `GlassSlider`/`GlassSwitch`/`GlassSegmentedControl` on the page or inside a `GlassContainer.card(surfaceStyle: solid)`; wallpaper cards are glass (`GlassContainer.card` premium), but **text/info cards use `GlassSurfaceStyle.solid`** (`GlassSurface` wrapper, `GlassGroupedSection(surfaceStyle: solid)`): premium frost fogs card text (发雾) and stale backdrop capture greys it while scrolling — the native iOS 27 inset-grouped card is a flat surface.
- Keep primary CTAs (import, apply wallpaper, save) in a fixed bottom location, never in a scrolling list: premium glass captures its backdrop and loses its tint while scrolling (保存按钮滑动丢色). On tab pages the import CTA is a `Positioned` overlay at the bottom of the body (just above the TAB); on pushed pages it lives in `GlassScaffold.bottomBar`.
- Use `GlassCircleButton` for all circular icon buttons: it enforces a square `SizedBox` and disables `anchorStretch`, otherwise the glass lens stretches into an oval.
- All glass surfaces use `GlassQuality.premium` with an own layer: the iOS 27 fog (`frost` / `frostOpacity`) only exists on the premium path — `standard` is the lightweight shader with **no backdrop texture** and reads as a flat tint. The page background is a flat colour and card content is opaque, so backdrop capture going stale while scrolling is not visible here. If a low-end device drops frames, cap via `GlassAdaptiveScope`, do not downgrade individual surfaces back to `standard`.
- Dark-mode glass in `main.dart` is calibrated "dark platter, lighter lens" (iOS 27 dark chrome): low glassColor alpha + low `frostOpacity`/`frostWeight` for platters, brighter `indicatorSettings` for the selected capsule. Do not reuse the light-mode fog recipe in dark — a white frost cloud over the dark page reads as milk-grey (发白) and makes the indicator darker than its platter.
- Changing native rendering requires a real-device check: debug and release/R8 can behave differently, and `build/` screenshots are manual artifacts, not source.
