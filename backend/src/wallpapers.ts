/** 壁纸目录：列表（游标分页）、详情、下载票据。客户端只拿 id。 */
import type { Env } from './env';
import { optionalUser } from './auth';
import { base64url, decodeSegment, fail, fromBase64url, json, utf8 } from './http';
import { signTicket, TICKET_TTL_MS } from './ticket';
import { davRequest } from './webdav';

/** 匿名下载在 downloads 表里的 user_id。 */
const ANON_USER_ID = 'anon';

interface WallpaperRow {
  id: string;
  title: string;
  author: string | null;
  type: string;
  version: string;
  size: number;
  cover_path: string | null;
  updated_at: number;
}

interface WallpaperSummaryRow {
  id: string;
  title: string;
  type: string;
  version: string;
  size: number;
}

/** 不外泄 webdav_path / cover_path：客户端只拿元数据、id 与“有没有封面”的布尔值。 */
const SELECT_COLUMNS = 'id, title, author, type, version, size, cover_path, updated_at';

function toItem(row: WallpaperRow) {
  return {
    id: row.id,
    title: row.title,
    author: row.author,
    type: row.type,
    version: row.version,
    size: row.size,
    // 只告诉客户端有没有封面，真实路径仍留在服务端；封面图走 /cover 代理。
    hasCover: typeof row.cover_path === 'string' && row.cover_path.length > 0,
    updatedAt: row.updated_at,
  };
}

export function encodeCursor(updatedAt: number, id: string): string {
  return base64url(utf8(`${updatedAt}:${id}`));
}

export function decodeCursor(raw: string | null): { updatedAt: number; id: string } | null {
  if (!raw) return null;
  try {
    const text = new TextDecoder().decode(fromBase64url(raw));
    const separator = text.indexOf(':');
    if (separator <= 0) return null;
    const updatedAt = Number(text.slice(0, separator));
    const id = text.slice(separator + 1);
    if (!Number.isFinite(updatedAt) || !id) return null;
    return { updatedAt, id };
  } catch {
    return null;
  }
}

export async function handleList(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const requested = Number(url.searchParams.get('limit') ?? '20');
  const limit = Number.isFinite(requested) ? Math.min(Math.max(Math.trunc(requested), 1), 50) : 20;
  const cursor = decodeCursor(url.searchParams.get('cursor'));

  const statement = cursor
    ? env.DB.prepare(
        `SELECT ${SELECT_COLUMNS} FROM wallpapers ` +
          'WHERE (updated_at < ?1 OR (updated_at = ?1 AND id < ?2)) ' +
          'ORDER BY updated_at DESC, id DESC LIMIT ?3',
      ).bind(cursor.updatedAt, cursor.id, limit + 1)
    : env.DB.prepare(
        `SELECT ${SELECT_COLUMNS} FROM wallpapers ORDER BY updated_at DESC, id DESC LIMIT ?1`,
      ).bind(limit + 1);

  const result = await statement.all<WallpaperRow>();
  const rows = result.results ?? [];
  const items = rows.slice(0, limit).map(toItem);
  const last = items[items.length - 1];
  const nextCursor = rows.length > limit && last ? encodeCursor(last.updatedAt, last.id) : null;

  return json({ items, nextCursor });
}

export async function handleDetail(
  request: Request,
  env: Env,
  rawId: string,
): Promise<Response> {
  const id = decodeSegment(rawId);
  const row = await env.DB.prepare(`SELECT ${SELECT_COLUMNS} FROM wallpapers WHERE id = ?1`)
    .bind(id)
    .first<WallpaperRow>();
  if (!row) return fail(404, 'wallpaper_not_found', '壁纸不存在');
  return json(toItem(row));
}

export async function handleTicket(
  request: Request,
  env: Env,
  rawId: string,
): Promise<Response> {
  // 可选鉴权：壁纸库是公开内容，匿名也能换票据；登录只是把下载记录
  // 归属到具体用户。票据本身仍然 HMAC 签名 + 5 分钟过期，防止被当作
  // 长期直链分发。
  const user = await optionalUser(request, env);

  const id = decodeSegment(rawId);
  const row = await env.DB.prepare(
    'SELECT id, title, type, version, size FROM wallpapers WHERE id = ?1',
  )
    .bind(id)
    .first<WallpaperSummaryRow>();
  if (!row) return fail(404, 'wallpaper_not_found', '壁纸不存在');

  const expiresAt = Date.now() + TICKET_TTL_MS;
  const ticket = await signTicket(env, {
    uid: user?.id ?? ANON_USER_ID,
    wid: id,
    exp: expiresAt,
  });
  return json({
    ticket,
    url: `/download/${encodeURIComponent(id)}?ticket=${encodeURIComponent(ticket)}`,
    expiresAt,
    size: row.size,
    version: row.version,
  });
}

/**
 * 封面代理：`GET /api/wallpapers/:id/cover`。
 *
 * 壁纸库列表要在下载前就显示预览，但 cover_path 不能下发给客户端，
 * 所以这里用 Worker 的只读 WebDAV 账号把封面流式代理出去。封面是公开
 * 资源，不需要票据；缓存 1 小时，列表滚动时不会反复打 WebDAV。
 */
export async function handleCover(
  request: Request,
  env: Env,
  rawId: string,
  ctx: ExecutionContext,
): Promise<Response> {
  const id = decodeSegment(rawId);
  const row = await env.DB.prepare('SELECT cover_path FROM wallpapers WHERE id = ?1')
    .bind(id)
    .first<{ cover_path: string | null }>();
  if (!row || !row.cover_path) return fail(404, 'cover_not_found', '该壁纸没有封面');

  const url = new URL(request.url);
  const cacheKey = new Request(new URL(`/api/wallpapers/${encodeURIComponent(id)}/cover`, url.origin).toString(), {
    method: 'GET',
  });
  const method = request.method.toUpperCase() === 'HEAD' ? 'HEAD' : 'GET';
  if (method === 'GET') {
    const hit = await caches.default.match(cacheKey);
    if (hit) return hit;
  }

  let upstream: Response;
  try {
    upstream = await davRequest(env, row.cover_path, { method });
  } catch (error) {
    console.warn('封面代理连接 WebDAV 失败', error);
    return fail(502, 'upstream_unavailable', '存储端无法连接');
  }
  if (upstream.status === 401 || upstream.status === 403) {
    await upstream.body?.cancel();
    return fail(502, 'upstream_denied', '存储端拒绝访问');
  }
  if (upstream.status !== 200) {
    await upstream.body?.cancel();
    return fail(upstream.status === 404 ? 404 : 502, 'cover_unavailable', '封面不可用');
  }

  const headers = new Headers();
  headers.set('content-type', upstream.headers.get('content-type') ?? 'image/png');
  const length = upstream.headers.get('content-length');
  if (length) headers.set('content-length', length);
  headers.set('cache-control', 'public, max-age=3600');
  headers.set('x-content-type-options', 'nosniff');

  const response = new Response(method === 'HEAD' ? null : upstream.body, {
    status: 200,
    headers,
  });
  if (method === 'GET' && response.body) {
    ctx.waitUntil(caches.default.put(cacheKey, response.clone()).catch(() => undefined));
  }
  return response;
}
