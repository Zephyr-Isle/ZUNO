/**
 * 下载：校验票据后把 Range 请求转发给 WebDAV，原样流式返回。
 *
 * 硬性要求（internal-docs/docs/backend.md §5）：
 * - 流式返回 upstream.body，绝不 arrayBuffer()（Worker 内存 128MB）；
 * - 206 / Content-Range / Accept-Ranges 原样透传，否则断点续传坏掉；
 * - 支持 HEAD；
 * - WebDAV 的 401/403 一律转 502，不透出内部认证细节；
 * - 并发上限默认 3（WebDAV 上行是唯一带宽瓶颈）。
 */
import type { Env } from './env';
import { fail } from './http';
import { verifyTicket } from './ticket';
import { davRequest } from './webdav';

const FORWARD_HEADERS = [
  'content-type',
  'content-length',
  'content-range',
  'accept-ranges',
  'etag',
  'last-modified',
] as const;

const DEFAULT_CONCURRENCY = 3;

let activeDownloads = 0;

async function withSlot<T>(limit: number, task: () => Promise<T>): Promise<T> {
  while (activeDownloads >= limit) {
    await new Promise<void>((resolve) => setTimeout(resolve, 20));
  }
  activeDownloads += 1;
  try {
    return await task();
  } finally {
    activeDownloads -= 1;
  }
}

function downloadConcurrency(env: Env): number {
  const parsed = Number(env.DOWNLOAD_CONCURRENCY ?? String(DEFAULT_CONCURRENCY));
  if (!Number.isFinite(parsed)) return DEFAULT_CONCURRENCY;
  return Math.min(Math.max(Math.trunc(parsed), 1), 8);
}

async function recordDownload(env: Env, userId: string, wallpaperId: string): Promise<void> {
  try {
    await env.DB.prepare('INSERT INTO downloads (user_id, wallpaper_id, at) VALUES (?1, ?2, ?3)')
      .bind(userId, wallpaperId, Date.now())
      .run();
  } catch (error) {
    console.warn('下载记录写入失败', error);
  }
}

export async function handleDownload(
  request: Request,
  env: Env,
  rawId: string,
  ctx: ExecutionContext,
): Promise<Response> {
  const url = new URL(request.url);
  const payload = await verifyTicket(env, url.searchParams.get('ticket') ?? '');
  if (!payload) return fail(403, 'invalid_ticket', '下载票据无效或已过期');

  let id: string;
  try {
    id = decodeURIComponent(rawId);
  } catch {
    return fail(400, 'invalid_id', '壁纸 id 不合法');
  }
  if (payload.wid !== id) return fail(403, 'invalid_ticket', '票据与壁纸不匹配');

  const row = await env.DB.prepare('SELECT id, webdav_path, size FROM wallpapers WHERE id = ?1')
    .bind(id)
    .first<{ id: string; webdav_path: string; size: number }>();
  if (!row) return fail(404, 'wallpaper_not_found', '壁纸不存在');

  const range = request.headers.get('range');
  const method = request.method.toUpperCase() === 'HEAD' ? 'HEAD' : 'GET';
  const cacheable = method === 'GET' && !range && env.CACHE_DOWNLOADS === 'true';
  const cache = caches.default;
  const cacheKey = new Request(new URL(`/download/${encodeURIComponent(id)}`, url.origin).toString(), {
    method: 'GET',
  });

  if (cacheable) {
    const hit = await cache.match(cacheKey);
    if (hit) {
      ctx.waitUntil(recordDownload(env, payload.uid, id));
      return hit;
    }
  }

  // 网络层失败（WebDAV 域名不可达/超时）会以异常抛出，不产生状态码；
  // 不接住的话会穿透到路由兜底变成 500 internal_error，绕过这里的
  // 502 错误映射设计。401/403/404 等状态码映射保持不变。
  let upstream: Response;
  try {
    upstream = await withSlot(downloadConcurrency(env), () =>
      davRequest(env, row.webdav_path, {
        method,
        // Range / Accept-Encoding 仍原样带上，但要知道：Workers 的 fetch 子请求
        // 会把这两个头剥掉（实测 WebDAV 收到的是整文件 GET + gzip），所以
        // 上游永远回 200 + 整个文件，206 只在本地 dev（node 运行时）才可能出现。
        // 客户端因此只能整包下载——不要承诺断点续传。
        headers: range
          ? { range, 'accept-encoding': 'identity' }
          : { 'accept-encoding': 'identity' },
      }),
    );
  } catch (error) {
    console.warn('下载代理连接 WebDAV 失败', error);
    return fail(502, 'upstream_unavailable', '存储端无法连接');
  }

  if (upstream.status === 401 || upstream.status === 403) {
    await upstream.body?.cancel();
    return fail(502, 'upstream_denied', '存储端拒绝访问');
  }
  if (upstream.status === 404) {
    await upstream.body?.cancel();
    return fail(404, 'file_missing', '壁纸文件已从存储端移除');
  }
  if (upstream.status !== 200 && upstream.status !== 206) {
    await upstream.body?.cancel();
    return fail(502, 'upstream_error', `存储端返回 ${upstream.status}`);
  }

  const headers = new Headers();
  for (const name of FORWARD_HEADERS) {
    const value = upstream.headers.get(name);
    if (value) headers.set(name, value);
  }
  if (!headers.has('content-type')) headers.set('content-type', 'application/octet-stream');
  headers.set(
    'cache-control',
    cacheable && upstream.status === 200 ? 'public, max-age=3600' : 'private, no-store',
  );
  headers.set('x-content-type-options', 'nosniff');

  const response = new Response(method === 'HEAD' ? null : upstream.body, {
    status: upstream.status,
    headers,
  });

  if (cacheable && upstream.status === 200 && response.body) {
    ctx.waitUntil(cache.put(cacheKey, response.clone()).catch(() => undefined));
  }
  if (method === 'GET') ctx.waitUntil(recordDownload(env, payload.uid, id));

  return response;
}
