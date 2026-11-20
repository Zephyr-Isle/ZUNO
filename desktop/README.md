# ZUNO 壁纸管理端（Tauri 2）

桌面管理端：浏览云端目录、预览（本地 / 远端）、本地压缩后直传 WebDAV、删除壁纸与本地包。
Flutter App 只是客户端——上传、删除这类管理操作全部在这里，App 里不提供入口。

## 功能

| 页面 | 能力 |
|---|---|
| 云端壁纸 | 分页拉全量目录、同步 WebDAV→D1、预览（5 分钟票据下载整包后本地解析）、按 id 删除（管理端直连 WebDAV 删包与封面，Worker 只删 D1） |
| 本地文件 | 选择目录列出 `.zuno` / `.zip`、预览视频/图片/HTML、上传并同步（未选封面时自动用包内预览图）、删除本地文件 |
| 从源目录打包 | 选一个含 `manifest.json` + `content/` 的目录 → 校验 → **重算 checksum** → **缺 `thumbnail.png` 时自动生成** → 压缩成 `.zuno` → 可选立即上传 |
| 设置 | API 地址、Admin Secret、WebDAV 地址/账号/密码、本地目录；只写应用私有配置目录 |

删除同时兼容 `.zuno` 与 `.zip`：后端 `POST /api/admin/delete` 会清理版本目录下两种扩展名的遗留包，避免 sync 把已删壁纸重新收录；本地删除也只接受这两种扩展名。

## 开发 / 构建

需要 Node 22+、Rust（stable）、WebView2（Windows 11 自带）。

```bash
cd desktop
npm install
npm run tauri dev      # 前端 Vite :1420 + Rust 调试窗口
npm run tauri build    # 产物：src-tauri/target/release/bundle/
```

只检查前端：`npm run build`（`tsc --noEmit` + Vite）。
只检查 Rust：`cd src-tauri && cargo check`。

## 上传链路（与 `docs/backend.md` 一致）

```
源目录 ──本地压缩包 + checksum──▶ <id>-<version>.zuno（缺图时自动生成 thumbnail.png）
       ──直传 WebDAV──▶ /zuno/packages/<id>/<version>/<file>.zuno
       ──封面：手动选，或自动提取包内预览图──▶ /zuno/covers/<id>.png|jpg
       ──POST /api/admin/sync──▶ D1 wallpapers 表
```

Worker 对 WebDAV 只读，**上传不经过 Worker**（免费版请求体限制）。
设置里的 WebDAV 账号必须能写 `/zuno`，与 Worker 用的只读账号可以是不同账号。

## 校验与预览

- 打包时复用 README §2 的规则：`content/` 下按相对包根 POSIX 路径排序，逐段 `路径 + 0x0A + 文件字节` 喂进同一个 SHA-256，写回 `manifest.checksum`。
- `schemaVersion / id / version / title / type / entry / content/` 都会校验，entry 不存在直接拒绝打包。
- 解压预览走 `safe_join`：拒绝绝对路径、反斜杠、`..` 与任何逃逸出临时目录的路径（Zip Slip）。
- 远端预览先换票据再流式下载整包（票据 5 分钟有效，不能当直链），之后与本地包走同一套预览逻辑。
- **自动预览图**：源目录没有 `thumbnail.png` 时按 `type` 生成并写进包——`video` 取首帧、`depth` 缩放颜色图（需 `PATH` 中有 `ffmpeg.exe`，输出统一 480×800 留边）；`html` 用系统 Edge / Chrome 无头模式真实渲染 entry 后截图（独立临时 profile，不干扰已开的浏览器）；`timed` 不渲染，留占位图标。生成失败只提示、不阻断打包，客户端导入时会补图（见主 README §5 第 9 条）。上传时若未手动选封面，会自动把包内预览图提取为 `/zuno/covers/<id>.png`。

## 配置与密钥

配置保存在各平台的应用配置目录，例如 Windows：

```
%APPDATA%\com.zuno.admin\config.json
```

Admin Secret 与 WebDAV 密码在本机明文保存（管理端工具，依赖机器可信）；不要把这个文件提交到仓库或同步到公共网盘。Worker 侧密钥仍只走 `wrangler secret`。
