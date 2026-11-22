/**
 * 用户系统：邮箱 + 密码。
 *
 * 文档 §6 给了三个选项；免费版 10ms CPU 下这里取方案 2：
 * PBKDF2-SHA256 降到 10000 次迭代（`PBKDF2_ITERATIONS` 可调），
 * 并加一层本 isolate 内的登录失败限流。上 Workers Paid 后应调回 100000。
 */
import type { Env } from './env';
import {
  fail,
  fromHex,
  json,
  randomToken,
  readJsonObject,
  sha256Hex,
  timingSafeEqual,
  toHex,
  utf8,
} from './http';

export const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
/** 邮箱不存在时也跑一次同代价的哈希，避免用响应时间枚举账号。 */
const DUMMY_SALT = '5a1f0c2d3b4e6f708192a3b4c5d6e7f8';
const LOGIN_WINDOW_MS = 60_000;
const LOGIN_MAX_FAILURES = 10;

export interface AuthUser {
  id: string;
  email: string;
}

interface UserRow {
  id: string;
  email: string;
  password_hash: string | null;
  password_salt: string | null;
}

const loginFailures = new Map<string, { count: number; resetAt: number }>();

function iterations(env: Env): number {
  const parsed = Number(env.PBKDF2_ITERATIONS ?? '10000');
  if (!Number.isFinite(parsed)) return 10_000;
  return Math.min(Math.max(Math.trunc(parsed), 1_000), 100_000);
}

export async function hashPassword(env: Env, password: string, saltHex: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', utf8(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: fromHex(saltHex), iterations: iterations(env), hash: 'SHA-256' },
    key,
    256,
  );
  return toHex(new Uint8Array(bits));
}

export async function createSession(
  env: Env,
  userId: string,
): Promise<{ token: string; expiresAt: number }> {
  const token = randomToken(32);
  const tokenHash = await sha256Hex(token);
  const now = Date.now();
  const expiresAt = now + SESSION_TTL_MS;
  await env.DB.prepare(
    'INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?1, ?2, ?3)',
  )
    .bind(tokenHash, userId, expiresAt)
    .run();
  // 顺手清掉该用户已过期的会话，省一次定时任务。
  await env.DB.prepare('DELETE FROM sessions WHERE user_id = ?1 AND expires_at < ?2')
    .bind(userId, now)
    .run();
  return { token, expiresAt };
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/** 成功返回用户，失败返回可直接返回的 401 响应。 */
export async function requireUser(request: Request, env: Env): Promise<AuthUser | Response> {
  if (!bearerToken(request)) return fail(401, 'unauthorized', '缺少 Bearer token');
  const user = await optionalUser(request, env);
  if (!user) return fail(401, 'unauthorized', '登录已失效，请重新登录');
  return user;
}

/**
 * 可选鉴权：带有效 Bearer 返回用户，否则返回 null。
 *
 * 下载票据走这条路径——壁纸库是公开内容，不登录也应该能下载；
 * 登录只是把下载记录归属到具体用户（匿名记作 `anon`）。
 * 注意不要用它保护写接口：那里必须用 [requireUser]。
 */
export async function optionalUser(request: Request, env: Env): Promise<AuthUser | null> {
  const token = bearerToken(request);
  if (!token) return null;
  const tokenHash = await sha256Hex(token);
  const row = await env.DB.prepare(
    'SELECT u.id AS id, u.email AS email FROM sessions s JOIN users u ON u.id = s.user_id ' +
      'WHERE s.token_hash = ?1 AND s.expires_at > ?2',
  )
    .bind(tokenHash, Date.now())
    .first<AuthUser>();
  return row ? { id: row.id, email: row.email } : null;
}

function loginBlocked(email: string): boolean {
  const entry = loginFailures.get(email);
  if (!entry) return false;
  if (entry.resetAt <= Date.now()) {
    loginFailures.delete(email);
    return false;
  }
  return entry.count >= LOGIN_MAX_FAILURES;
}

function recordLoginFailure(email: string): void {
  const now = Date.now();
  const entry = loginFailures.get(email);
  if (!entry || entry.resetAt <= now) {
    loginFailures.set(email, { count: 1, resetAt: now + LOGIN_WINDOW_MS });
  } else {
    entry.count += 1;
  }
  evictLoginFailures(now);
}

/** 限流表常驻内存上限（isolate 内）。 */
const LOGIN_FAILURES_MAX = 5_000;

/**
 * 限流表只在 isolate 内有效，需要控制常驻内存。此前超限时整体 clear()：
 * 攻击者可以先用 5000 个假邮箱灌满限流表——clear 连受害者的失败计数一起
 * 抹掉，暴力破解防护被打空（受害者密码可反复试 10 次）。
 * 现在改为：先清过期条目；仍超限则淘汰计数最低的一批——假邮箱喷射的条目
 * count 通常是 1，受害者的失败计数远高于此，不会被无差别清空。
 */
function evictLoginFailures(now: number): void {
  if (loginFailures.size <= LOGIN_FAILURES_MAX) return;
  for (const [email, entry] of loginFailures) {
    if (entry.resetAt <= now) loginFailures.delete(email);
  }
  if (loginFailures.size > LOGIN_FAILURES_MAX) {
    const excess = loginFailures.size - LOGIN_FAILURES_MAX;
    const lowest = [...loginFailures.entries()]
      .sort((a, b) => a[1].count - b[1].count)
      .slice(0, excess);
    for (const [email] of lowest) loginFailures.delete(email);
  }
}

function clearLoginFailures(email: string): void {
  loginFailures.delete(email);
}

export async function handleRegister(request: Request, env: Env): Promise<Response> {
  const body = await readJsonObject(request);
  const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  if (!EMAIL_PATTERN.test(email) || email.length > 254) {
    return fail(400, 'invalid_email', '邮箱格式不正确');
  }
  if (password.length < 8 || password.length > 128) {
    return fail(400, 'invalid_password', '密码长度需为 8–128 个字符');
  }

  const salt = toHex(crypto.getRandomValues(new Uint8Array(16)));
  const passwordHash = await hashPassword(env, password, salt);
  const id = crypto.randomUUID();
  try {
    await env.DB.prepare(
      'INSERT INTO users (id, email, password_hash, password_salt, created_at) VALUES (?1, ?2, ?3, ?4, ?5)',
    )
      .bind(id, email, passwordHash, salt, Date.now())
      .run();
  } catch (error) {
    if (String(error).includes('UNIQUE')) return fail(409, 'email_taken', '该邮箱已注册');
    throw error;
  }

  const session = await createSession(env, id);
  return json(
    { token: session.token, expiresAt: session.expiresAt, user: { id, email } },
    { status: 201 },
  );
}

export async function handleLogin(request: Request, env: Env): Promise<Response> {
  const body = await readJsonObject(request);
  const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  if (!email || !password) return fail(400, 'invalid_credentials', '邮箱或密码为空');
  if (loginBlocked(email)) {
    return fail(429, 'too_many_attempts', '尝试过于频繁，请稍后再试');
  }

  const row = await env.DB.prepare(
    'SELECT id, email, password_hash, password_salt FROM users WHERE email = ?1',
  )
    .bind(email)
    .first<UserRow>();

  if (!row) {
    await hashPassword(env, password, DUMMY_SALT);
    recordLoginFailure(email);
    return fail(401, 'invalid_credentials', '邮箱或密码不正确');
  }

  const stored = fromHex(row.password_hash ?? '');
  const actual = fromHex(await hashPassword(env, password, row.password_salt ?? DUMMY_SALT));
  if (stored.length === 0 || !timingSafeEqual(stored, actual)) {
    recordLoginFailure(email);
    return fail(401, 'invalid_credentials', '邮箱或密码不正确');
  }

  clearLoginFailures(email);
  const session = await createSession(env, row.id);
  return json({
    token: session.token,
    expiresAt: session.expiresAt,
    user: { id: row.id, email: row.email },
  });
}

export async function handleLogout(request: Request, env: Env): Promise<Response> {
  const token = bearerToken(request);
  if (!token) return fail(401, 'unauthorized', '缺少 Bearer token');
  await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?1')
    .bind(await sha256Hex(token))
    .run();
  return json({ ok: true });
}
