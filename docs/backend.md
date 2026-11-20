# ZUNO 云端方案（Workers + D1 + WebDAV）

本文只描述云端：用户系统、壁纸目录、下载分发。渲染与包格式见 [README](../README.md)。
存储固定为三件套，**不使用 R2**：

| 组件 | 职责 |
| --- | --- |
| **Cloudflare Workers** | API 入口、登录鉴权、壁纸列表、下载票据、整文件流式代理 |
| **D1** | 用户、会话、壁纸元数据、下载记录 |
| **WebDAV** | 唯一的 `.zuno` 文件与封面存储，仅管理端上传 |

## 1. 数据流

```
管理端 ──上传──▶ WebDAV (/zuno/...)
App ──登录 / 列表──▶ Worker ──读写──▶ D1
App ──下载（带票据）──▶ Worker ──流式代理──▶ WebDAV
```

- App 永远不接触 WebDAV 地址和账号密码。
- 管理端上传不经过 Worker（免费版请求体上限 100MB）。
- Worker 对 WebDAV 只读，不提供上传接口。

## 2. WebDAV 目录约定

```
/zuno/
  packages/<id>/<version>/<id>-<version>.zuno
  covers/<id>.jpg
```

- 使用独立账号，只授权 `/zuno`，关闭目录浏览。
- 必须 HTTPS + 长随机密码；凭据只存在 Worker Secret。
- `webdav_path` 存在 D1，客户端只拿壁纸 id。
- 路径含中文/空格时按段 `encodeURIComponent`，不要整串编码。

## 3. D1 表结构

```sql
CREATE TABLE users (
  id            TEXT PRIMARY KEY,
  email         TEXT UNIQUE,
  password_hash TEXT,
  password_salt TEXT,
  created_at    INTEGER NOT NULL
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX idx_sessions_user ON sessions(user_id);

CREATE TABLE wallpapers (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  author      TEXT,
  type        TEXT NOT NULL,          -- video / html / depth / timed
  version     TEXT NOT NULL,
  size        INTEGER NOT NULL,
  webdav_path TEXT NOT NULL,
  cover_path  TEXT,
  updated_at  INTEGER NOT NULL
);
-- 目录接口按 (updated_at DESC, id DESC) keyset 分页，必须有对应索引避免全表排序。
CREATE INDEX idx_wallpapers_updated ON wallpapers(updated_at DESC, id DESC);

CREATE TABLE downloads (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      TEXT NOT NULL,
  wallpaper_id TEXT NOT NULL,
  at           INTEGER NOT NULL
);
CREATE INDEX idx_downloads_user ON downloads(user_id, at);
-- 管理端删除按 wallpaper_id 清下载记录，需要这条索引避免全表扫描。
CREATE INDEX idx_downloads_wallpaper ON downloads(wallpaper_id);
```

`wallpapers` 可由管理端调用 `POST /api/admin/sync` 触发 WebDAV `PROPFIND` 后写入；早期也可以手动维护。

## 4. Worker API

| 方法 | 路径 | 鉴权 | 说明 |
| --- | --- | --- | --- |
| GET | `/health` | 无 | 健康检查 |
| POST | `/api/auth/register` | 无 | 注册 |
| POST | `/api/auth/login` | 无 | 登录，返回 Bearer token |
| POST | `/api/auth/logout` | Bearer | 删除会话 |
| GET | `/api/wallpapers` | 可选 | 列表，游标分页 |
| GET | `/api/wallpapers/:id` | 可选 | 详情 |
| POST | `/api/wallpapers/:id/ticket` | 可选 | 签发 5 分钟下载票据；匿名登录都可用 |
| GET | `/download/:id?ticket=...` | 票据 | 代理 WebDAV，整文件流式下载（见 §5 平台限制） |
| POST | `/api/admin/sync` | Admin Secret | 扫描 WebDAV 并更新 D1；`?id=` 同步单包、`?offset=&limit=` 分批扫描（`.zuno` 与 `.zip` 都收录） |

同步读 manifest 的第一选择是版本目录下的 `manifest.json` **旁车文件**（管理端上传包时同目录写入，普通 GET 即可）。没有旁车才回退到“从 ZIP 中央目录抠 manifest”，但这条回退路径在线上并不便宜：**Workers 的 fetch 子请求会剥掉 `Range` 和 `Accept-Encoding`**，三次 Range 实际是三次整文件下载，因此 `readManifestFromWebdav` 只对 ≤16MB 的包尝试，更大的包直接跳过。管理端上传时务必写旁车；老包可以补一次 `manifest.json`。

`sync` 按 WebDAV 修改时间倒序分页（默认 5 个包/次），响应带 `nextOffset`，调用方循环到 `null` 为止。免费版单请求只有 50 次子请求，一次扫全量很容易在中途被截断——这正是“包已上传、D1 里却没有”的常见原因。
| POST | `/api/admin/delete` | Admin Secret | 按 id 删除 D1 记录与下载记录，请求体 `{"id":"..."}`；WebDAV 文件由管理端直连删除 |

会话：随机 32 字节 token，D1 只存 `SHA-256(token)`；请求带 `Authorization: Bearer <token>`。客户端可选登录，token 存应用私有 prefs（`zuno_auth`，不进 `zuno_config`）：当前客户端默认走匿名下载，登录仅用于把下载记录归属到具体用户。

## 5. 下载实现

### 票据

```ts
// payload = { uid, wid, exp }
// ticket = base64url(payload) + "." + base64url(HMAC_SHA256(payload, TICKET_SECRET))
```

- 有效期 5 分钟，只允许下载指定壁纸。
- 不绑定 IP（移动网络切换会误伤）。
- 允许匿名：无 Bearer 或 token 失效时 `uid` 记为 `anon`，仍然签发；票据签名与过期规则不变，所以不能当长期直链用。
- 校验失败返回 403，不透露 WebDAV 细节。

### 下载代理（平台不支持 Range）

曾按“转发 Range、原样返回 206”设计，实测不成立：Workers 的 `fetch` 子请求会剥掉 `Range` 和 `Accept-Encoding`，WebDAV 收到的永远是整文件 GET（带 gzip），返回 200。Worker 能看到客户端的 `Range`，却无法让上游只发一段。

因此下载接口的实际契约是：

- **整文件流式返回** `upstream.body`，禁止 `arrayBuffer()`（Worker 内存 128MB）。
- 不再承诺 `206` / 断点续传；客户端只做整包下载，失败就删掉重来。
- 支持 `HEAD`，下载器会先探测大小。
- WebDAV 的 401/403 转成 502，不要把内部认证信息透给客户端。
- 公共壁纸可用 `caches.default` 缓存，缓存 key 去掉 `ticket` 参数，避免缓存私有响应。
- 并发下载数做上限（例如 2–3），WebDAV 上行是唯一带宽瓶颈。

```ts
const upstream = await fetch(`${WEBDAV_BASE}/${encodePath(row.webdav_path)}`, {
  method: request.method, // GET 或 HEAD
  headers: { Authorization: `Basic ${btoa(`${env.WEBDAV_USER}:${env.WEBDAV_PASS}`)}` },
});
```

## 6. 用户系统与免费版限制

- 免费版 Workers 单请求 **10ms CPU**，PBKDF2 十万次迭代会超时（1102）。
- 三个选择：
  1. **匿名设备 ID**（推荐先做）：D1 存 `device_id`，下载计数/收藏可用，不做密码。
  2. **邮箱 + 密码**：迭代降到约 1 万次并加登录限流，安全性打折。
  3. **Workers Paid**（$5/月）：CPU 30 秒，可正常做密码哈希。
- 邮箱/短信验证码需要额外服务，不在三件套内。
- D1 免费额度：5GB 存储、每天 500 万行读、10 万行写；按行扫描计费，`email`、`token_hash`、`wallpapers.id` 必须有索引。

## 7. 部署配置

`wrangler.toml`（仓库只提供 `backend/wrangler.toml.example`，复制后填真实值；`wrangler.toml` 本身已被 gitignore）：

```toml
name = "zuno-api"
main = "src/index.ts"
compatibility_date = "2026-01-01"

[[d1_databases]]
binding = "DB"
database_name = "zuno"
database_id = "<D1_DATABASE_ID>"

[vars]
WEBDAV_BASE = "https://dav.example.com/zuno"
```

Secret：

```bash
wrangler secret put WEBDAV_USER
wrangler secret put WEBDAV_PASS
wrangler secret put TICKET_SECRET
wrangler secret put ADMIN_SECRET
```

本地开发用 `wrangler dev` + `--local`，D1 用 `wrangler d1 execute zuno --local --file=schema.sql` 初始化。

## 8. 容量与限制

- **D1**：只存元数据，5GB 足够几十万条，不是瓶颈。
- **Worker**：免费 10 万请求/天；登录、列表、每次下载各算一次。
- **WebDAV**：存储和带宽的唯一来源。家宽上行 30Mbps ≈ 3.75MB/s，50MB 包约 13 秒/人，3 人并发就开始排队。
- Cloudflare 免费域名在大陆可能绕路；上线前用国内网络实测 50MB 文件的下载速度。
- 第三方 WebDAV（坚果云等）通常禁止外链/大流量代理，先确认服务条款。

## 9. 实施顺序

1. 建 D1 表，Worker 跑通 `/health` 与 `/api/wallpapers`。
2. 管理端上传 WebDAV，手动写入 D1 元数据。
3. 实现登录、票据与下载代理，用 `curl` 验证整文件能流式下完（不要按 206 验收，见 §5）。
4. Flutter 端拉列表 → 下载到临时目录 → 交给 `importZunoPackage` 导入。
5. 需要自动收录时再加 `PROPFIND` 同步与 `POST /api/admin/sync`（上传后按 `?id=` 单包同步）。

## 10. 客户端接入要点

- 下载按整包处理（服务端不承诺 Range/断点续传），失败删掉临时文件重来。
- 下载完成后再调用现有导入流程，不要在下载过程中解析 ZIP。
- 失败时清理临时文件，避免占满存储。
- 服务端地址和版本号做成可配置，方便切换环境。
