# ZUNO 后端（Workers + D1 + WebDAV）

接口契约、表结构、票据与代理规则以 [`docs/backend.md`](../docs/backend.md) 为准，本文件只写怎么跑起来。
三件套固定：Workers 做 API / 鉴权 / Range 代理，D1 存元数据，WebDAV 存 `.zuno` 与封面，**不使用 R2**。
Worker 对 WebDAV 只读：上传由管理端直连完成，这里没有上传接口。

## 目录

```
backend/
├── schema.sql              # D1 表结构（与文档 §3 一致）
├── wrangler.toml.example   # Worker 配置模板（复制为 wrangler.toml 后填真实值）
├── .dev.vars.example       # 本地 secret 模板（复制为 .dev.vars）
├── src/
│   ├── index.ts            # 路由表（文档 §4）
│   ├── auth.ts             # 注册 / 登录 / 登出 / 会话
│   ├── ticket.ts           # HMAC 下载票据（5 分钟）
│   ├── wallpapers.ts       # 列表（游标分页）/ 详情 / 票据签发
│   ├── download.ts         # 票据校验 + Range 流式代理
│   ├── sync.ts             # POST /api/admin/sync（PROPFIND → D1）
│   ├── admin-delete.ts     # POST /api/admin/delete（只删 D1，文件由管理端直连删）
│   ├── webdav.ts           # Basic 认证、PROPFIND 解析、Range 读取
│   ├── zip.ts              # 只读 .zuno 的 manifest（3 次 Range）
│   ├── http.ts             # JSON / 编码 / 常量时间比较
│   └── env.ts              # 绑定与变量类型
└── tool/stub-webdav.mjs    # 本地联调的只读 WebDAV 桩
```

## 首次部署

```bash
cd backend
npm install
cp wrangler.toml.example wrangler.toml   # 再填 database_id / 域名 / WEBDAV_BASE

# 1) 建 D1，把返回的 database_id 填进 wrangler.toml
npx wrangler d1 create zuno

# 2) 建表（本地 / 线上各一次）
npm run db:init:local
npm run db:init:remote

# 3) Secret（值不要进仓库，也不要发在聊天里）
npx wrangler secret put WEBDAV_USER
npx wrangler secret put WEBDAV_PASS
npx wrangler secret put TICKET_SECRET      # 32 字节以上随机串
npx wrangler secret put ADMIN_SECRET       # 调用 /api/admin/sync 用

# 4) 把 wrangler.toml 的 WEBDAV_BASE 改成 https://dav.example.com/zuno
npm run deploy
```

WebDAV 侧：独立账号、只授权 `/zuno`、关闭目录浏览、必须 HTTPS + 长随机密码。
目录约定见文档 §2：`packages/<id>/<version>/<id>-<version>.zuno`、`covers/<id>.jpg`。

## 本地开发

```bash
cp wrangler.toml.example wrangler.toml   # 本地开发也必须有这个文件，wrangler 才能启动
cp .dev.vars.example .dev.vars   # 填 WEBDAV_USER / WEBDAV_PASS / TICKET_SECRET / ADMIN_SECRET
npm run db:init:local
npm run dev                      # http://127.0.0.1:8787
```

没有真实 WebDAV 时，用桩服务联调（把示例包按目录约定摆好）：

```bash
mkdir -p .tmp-dav/packages/com.zuno.sample.depth/1.0.0
cp ../samples/sample_depth.zuno .tmp-dav/packages/com.zuno.sample.depth/1.0.0/com.zuno.sample.depth-1.0.0.zuno

WEBDAV_USER=zuno-reader WEBDAV_PASS=dev-pass node tool/stub-webdav.mjs .tmp-dav 8799

# 另开一个终端：把 Worker 指向桩
npx wrangler dev --var WEBDAV_BASE:http://127.0.0.1:8799/zuno
```

冒烟（文档 §9 的验收顺序）：

```bash
curl -s http://127.0.0.1:8787/health

curl -s -X POST http://127.0.0.1:8787/api/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"a@example.com","password":"12345678"}'

curl -s -X POST http://127.0.0.1:8787/api/admin/sync \
  -H "x-admin-secret: $ADMIN_SECRET"

curl -s http://127.0.0.1:8787/api/wallpapers          # 目录来自 D1
curl -s -X POST http://127.0.0.1:8787/api/wallpapers/com.zuno.sample.depth/ticket \
  -H "authorization: Bearer $TOKEN"                    # 拿 ticket/url

# 下载：整文件流式下发（服务端不承诺 Range / 206，见文档 §5）
curl -s -D - -o /tmp/zuno-download.zuno \
  "http://127.0.0.1:8787/download/com.zuno.sample.depth?ticket=$TICKET"
# 预期 200 + Content-Length，文件大小与 WebDAV 上的整包一致。
# 带 Range 的请求也只会得到 200 整文件：Workers 的 fetch 子请求会剥掉 Range。
```

## 实现取舍

- **密码哈希**：文档 §6 的方案 2——PBKDF2-SHA256 **10000 次**（`PBKDF2_ITERATIONS` 可调），
  因为免费版单请求只有 10ms CPU。同时加了 isolate 内的登录失败限流（10 次/分钟/邮箱，尽力而为）。
  升级到 Workers Paid 后应把迭代次数调到 100000。
- **同步**：`POST /api/admin/sync?limit=10` 只扫前 10 个包目录（最大 20）。每个包需要
  3 次 PROPFIND + 3 次 Range 请求，免费版 50 子请求/次的上限决定了必须分批。
  `title / author / type / version` 取自 `.zuno` 内的 `manifest.json`（不下载整包）；
  `size / updated_at` 取 PROPFIND；封面按 `covers/<id>.jpg` 记录，缺失为 null。
- **不做的事**：不写 WebDAV、不提供上传接口、不返回 `webdav_path` / `cover_path`、
  不在 Worker 里解析 ZIP 之外的包内容；文档 §4 没有封面接口，所以列表也不返回封面 URL。
- **缓存**：`CACHE_DOWNLOADS="true"` 时整文件 GET（无 Range）走 `caches.default`，
  key 是不含 ticket 的 `/download/<id>`；带 Range 的请求永远直连 WebDAV。
- **并发**：`DOWNLOAD_CONCURRENCY`（默认 3）限制单个 isolate 同时在途的 WebDAV 下载。

## 门禁

```bash
npm run typecheck    # tsc --noEmit（wrangler 负责打包，不产出 dist）
```

后端不参与 Flutter 构建，`flutter analyze` / `flutter test` 不会覆盖这里的 Kotlin/TypeScript。
