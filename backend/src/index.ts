import { handleAdminDelete } from './admin-delete';
import { handleLogin, handleLogout, handleRegister } from './auth';
import { handleDownload } from './download';
import type { Env } from './env';
import { decodeSegment, fail, json, methodNotAllowed, MissingConfigError } from './http';
import { handleAdminSync } from './sync';
import { handleCover, handleDetail, handleList, handleTicket } from './wallpapers';

const TICKET_ROUTE = /^\/api\/wallpapers\/([^/]+)\/ticket$/;
const COVER_ROUTE = /^\/api\/wallpapers\/([^/]+)\/cover$/;
const WALLPAPER_ROUTE = /^\/api\/wallpapers\/([^/]+)$/;
const DOWNLOAD_ROUTE = /^\/download\/([^/]+)$/;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname.length > 1 ? url.pathname.replace(/\/+$/, '') : url.pathname;
    const method = request.method.toUpperCase();

    try {
      if (path === '/health') {
        if (method !== 'GET') return methodNotAllowed(['GET']);
        const startedAt = Date.now();
        try {
          await env.DB.prepare('SELECT 1').run();
        } catch (error) {
          console.error('健康检查：D1 不可用', error);
          return json({ ok: false, database: 'unavailable' }, { status: 503 });
        }
        return json({
          ok: true,
          service: 'zuno-api',
          database: 'ok',
          latencyMs: Date.now() - startedAt,
        });
      }

      if (path === '/api/auth/register') {
        return method === 'POST' ? await handleRegister(request, env) : methodNotAllowed(['POST']);
      }
      if (path === '/api/auth/login') {
        return method === 'POST' ? await handleLogin(request, env) : methodNotAllowed(['POST']);
      }
      if (path === '/api/auth/logout') {
        return method === 'POST' ? await handleLogout(request, env) : methodNotAllowed(['POST']);
      }

      if (path === '/api/wallpapers') {
        return method === 'GET' ? await handleList(request, env) : methodNotAllowed(['GET']);
      }

      const ticketMatch = TICKET_ROUTE.exec(path);
      if (ticketMatch) {
        if (method !== 'POST') return methodNotAllowed(['POST']);
        return await handleTicket(request, env, ticketMatch[1] ?? '');
      }

      const coverMatch = COVER_ROUTE.exec(path);
      if (coverMatch) {
        if (method !== 'GET' && method !== 'HEAD') return methodNotAllowed(['GET', 'HEAD']);
        return await handleCover(request, env, coverMatch[1] ?? '', ctx);
      }

      const wallpaperMatch = WALLPAPER_ROUTE.exec(path);
      if (wallpaperMatch) {
        if (method !== 'GET') return methodNotAllowed(['GET']);
        return await handleDetail(request, env, wallpaperMatch[1] ?? '');
      }

      const downloadMatch = DOWNLOAD_ROUTE.exec(path);
      if (downloadMatch) {
        if (method !== 'GET' && method !== 'HEAD') return methodNotAllowed(['GET', 'HEAD']);
        return await handleDownload(request, env, decodeSegment(downloadMatch[1] ?? ''), ctx);
      }

      if (path === '/api/admin/sync') {
        return method === 'POST' ? await handleAdminSync(request, env) : methodNotAllowed(['POST']);
      }
      if (path === '/api/admin/delete') {
        return method === 'POST'
          ? await handleAdminDelete(request, env)
          : methodNotAllowed(['POST']);
      }

      return fail(404, 'not_found', '接口不存在');
    } catch (error) {
      if (error instanceof MissingConfigError) {
        console.error('缺少配置', error.names);
        return fail(500, 'server_misconfigured', '服务端缺少必需配置', {
          missing: error.names,
        });
      }
      console.error('未处理的异常', error);
      return fail(500, 'internal_error', '服务器内部错误');
    }
  },
} satisfies ExportedHandler<Env>;
