/**
 * POST /api/admin/delete：只删 D1 里的壁纸元数据与下载记录。
 *
 * WebDAV 文件由桌面管理端用自己的写账号直连删除（PROPFIND 找包/封面，
 * 再 DELETE）——Worker 对 WebDAV 始终保持只读，这里不发起任何写入。
 */
import type { Env } from './env';
import { fail, json, readJsonObject, requireConfig, timingSafeEqual, utf8 } from './http';

export async function handleAdminDelete(request: Request, env: Env): Promise<Response> {
  requireConfig(env, ['ADMIN_SECRET']);
  const provided = request.headers.get('x-admin-secret') ?? '';
  if (!timingSafeEqual(utf8(provided), utf8(env.ADMIN_SECRET))) {
    return fail(403, 'forbidden', 'Admin Secret 不正确');
  }

  const body = await readJsonObject(request, 4 * 1024);
  const id = typeof body?.id === 'string' ? body.id.trim() : '';
  if (!id || id.length > 200) return fail(400, 'invalid_id', 'id 不合法');

  const row = await env.DB.prepare('SELECT id FROM wallpapers WHERE id = ?1')
    .bind(id)
    .first<{ id: string }>();
  if (!row) return fail(404, 'wallpaper_not_found', '壁纸不存在');

  // batch = 单事务：两条 DELETE 原子生效。此前顺序执行时，第二条失败
  // （D1 瞬时错误）会留下"下载记录已清、壁纸行还在"的半删除状态——目录
  // 仍列出它、票据照常签发，而下载历史已经丢失。
  await env.DB.batch([
    env.DB.prepare('DELETE FROM downloads WHERE wallpaper_id = ?1').bind(id),
    env.DB.prepare('DELETE FROM wallpapers WHERE id = ?1').bind(id),
  ]);

  return json({ deleted: id });
}
