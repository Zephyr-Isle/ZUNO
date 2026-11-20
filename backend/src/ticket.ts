/**
 * 下载票据：`base64url(payload) + "." + base64url(HMAC_SHA256(payload, TICKET_SECRET))`。
 * 5 分钟有效、只允许下载指定壁纸、不绑定 IP（移动网络切换会误伤）。
 */
import type { Env } from './env';
import {
  base64url,
  fromBase64url,
  requireConfig,
  timingSafeEqual,
  utf8,
} from './http';

export const TICKET_TTL_MS = 5 * 60 * 1000;

export interface TicketPayload {
  uid: string;
  wid: string;
  exp: number;
}

async function hmac(secret: string, data: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    'raw',
    utf8(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, data));
}

export async function signTicket(env: Env, payload: TicketPayload): Promise<string> {
  requireConfig(env, ['TICKET_SECRET']);
  const body = utf8(JSON.stringify({ uid: payload.uid, wid: payload.wid, exp: payload.exp }));
  const signature = await hmac(env.TICKET_SECRET, body);
  return `${base64url(body)}.${base64url(signature)}`;
}

/** 任何异常都当成无效票据：调用方统一返回 403，不透露内部细节。 */
export async function verifyTicket(env: Env, ticket: string): Promise<TicketPayload | null> {
  if (!ticket) return null;
  requireConfig(env, ['TICKET_SECRET']);
  const parts = ticket.split('.');
  if (parts.length !== 2) return null;
  const [bodyPart, signaturePart] = parts;
  if (!bodyPart || !signaturePart) return null;

  let body: Uint8Array;
  let signature: Uint8Array;
  try {
    body = fromBase64url(bodyPart);
    signature = fromBase64url(signaturePart);
  } catch {
    return null;
  }

  const expected = await hmac(env.TICKET_SECRET, body);
  if (!timingSafeEqual(expected, signature)) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder().decode(body));
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;

  const record = parsed as Record<string, unknown>;
  const { uid, wid, exp } = record;
  if (typeof uid !== 'string' || typeof wid !== 'string' || typeof exp !== 'number') return null;
  if (!Number.isFinite(exp) || exp <= Date.now()) return null;
  return { uid, wid, exp };
}
