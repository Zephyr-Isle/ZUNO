/** Worker 的绑定与变量。Secret 走 `wrangler secret put`，本地走 `.dev.vars`。 */
export interface Env {
  /** D1：用户、会话、壁纸元数据、下载记录。 */
  DB: D1Database;
  /** WebDAV 根地址，例如 https://dav.example.com/zuno（不含末尾斜杠）。 */
  WEBDAV_BASE: string;
  /** WebDAV 只读账号。 */
  WEBDAV_USER: string;
  WEBDAV_PASS: string;
  /** 下载票据 HMAC 密钥。 */
  TICKET_SECRET: string;
  /** 管理端同步密钥。 */
  ADMIN_SECRET: string;
  /** PBKDF2 迭代次数，默认 10000（免费版 CPU 限制）。 */
  PBKDF2_ITERATIONS?: string;
  /** 本 isolate 内同时代理的 WebDAV 下载数，默认 3。 */
  DOWNLOAD_CONCURRENCY?: string;
  /** "true" 时整文件 GET 走 caches.default。 */
  CACHE_DOWNLOADS?: string;
}
