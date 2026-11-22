/** 通用 HTTP / 编码工具。 */

export class MissingConfigError extends Error {
  constructor(readonly names: readonly string[]) {
    super(`缺少必需配置: ${names.join(', ')}`);
    this.name = 'MissingConfigError';
  }
}

export function json(body: unknown, init?: ResponseInit): Response {
  const headers = new Headers(init?.headers);
  if (!headers.has('content-type')) headers.set('content-type', 'application/json; charset=utf-8');
  if (!headers.has('cache-control')) headers.set('cache-control', 'no-store');
  return new Response(JSON.stringify(body), { ...init, headers });
}

export function fail(
  status: number,
  code: string,
  message: string,
  extra?: Record<string, unknown>,
): Response {
  return json({ error: code, message, ...extra }, { status });
}

export function methodNotAllowed(allowed: readonly string[]): Response {
  const response = fail(405, 'method_not_allowed', `只支持 ${allowed.join(' / ')}`);
  response.headers.set('allow', allowed.join(', '));
  return response;
}

/** Secret 缺失时抛 MissingConfigError，由入口统一转成 500 server_misconfigured。 */
export function requireConfig(env: object, names: readonly string[]): void {
  const record = env as Record<string, unknown>;
  const missing = names.filter((name) => {
    const value = record[name];
    return typeof value !== 'string' || value.length === 0;
  });
  if (missing.length > 0) throw new MissingConfigError(missing);
}

export function utf8(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

export function toHex(bytes: Uint8Array): string {
  let out = '';
  for (const byte of bytes) out += byte.toString(16).padStart(2, '0');
  return out;
}

export function fromHex(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) return new Uint8Array();
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i += 1) {
    const parsed = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
    if (Number.isNaN(parsed)) return new Uint8Array();
    out[i] = parsed;
  }
  return out;
}

export function base64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

export function base64url(bytes: Uint8Array): string {
  return base64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function fromBase64url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i);
  return out;
}

export function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  // 长度不匹配时提前返回会泄露密钥长度（admin 端点直接比较攻击者可控的
  // x-admin-secret 头）。零填充到同一长度再比对：耗时只取决于较长一侧，
  // 长度不等与内容不等在时序上不可区分。
  const max = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < max; i += 1) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', utf8(value));
  return toHex(new Uint8Array(digest));
}

export function randomToken(byteLength = 32): string {
  return base64url(crypto.getRandomValues(new Uint8Array(byteLength)));
}

/**
 * 按段编码 WebDAV 路径：中文/空格逐段 encodeURIComponent，保留 `/`。
 * 拒绝空段与 `.` / `..`，避免路径逃逸；含反斜杠的段同样拒绝——部分
 * Windows/IIS 系 WebDAV 实现把 `\` 当分隔符，`a\..\..\evil` 会被还原成
 * 目录穿越。
 */
export function encodePath(value: string): string {
  const segments = value.replace(/^\/+/, '').split('/');
  return segments
    .map((segment) => {
      if (segment === '' || segment === '.' || segment === '..' || segment.includes('\\')) {
        throw new Error(`非法路径段: ${segment}`);
      }
      return encodeURIComponent(segment);
    })
    .join('/');
}

export async function readJsonObject(
  request: Request,
  maxBytes = 16 * 1024,
): Promise<Record<string, unknown> | null> {
  // 以字节为界、边读边计数：此前先 request.text() 全量缓冲再按 text.length
  // （UTF-16 码元）比较——增补平面字符一个码元占 4 字节，实际字节量可达
  // 预算的 4 倍；chunked 请求没有 content-length，预检被完全绕过。
  const reader = request.body?.getReader();
  if (!reader) return null;
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    const parsed: unknown = JSON.parse(new TextDecoder().decode(merged));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function decodeSegment(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}
