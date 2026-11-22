/**
 * WebDAV 只读封装。Worker 只做 GET / HEAD / PROPFIND：
 * 上传由管理端直连 WebDAV，这里不提供任何写入路径。
 */
import type { Env } from './env';
import { base64, encodePath, requireConfig, utf8 } from './http';

const PROPFIND_BODY = `<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>`;

const RESPONSE_BLOCK = /<(?:[A-Za-z0-9_-]+:)?response\b[^>]*>([\s\S]*?)<\/(?:[A-Za-z0-9_-]+:)?response>/gi;
const COLLECTION_TAG = /<(?:[A-Za-z0-9_-]+:)?collection\b[^>]*\/?>/i;

export class DavError extends Error {
  constructor(readonly status: number) {
    super(`WebDAV 返回 ${status}`);
    this.name = 'DavError';
  }
}

export interface DavEntry {
  /** 相对 WEBDAV_BASE 的路径，例如 packages/demo/1.0.0/demo-1.0.0.zuno。 */
  path: string;
  name: string;
  isDir: boolean;
  size: number | null;
  lastModified: number | null;
}

function davBase(env: Env): { base: string; authorization: string } {
  requireConfig(env, ['WEBDAV_BASE', 'WEBDAV_USER', 'WEBDAV_PASS']);
  return {
    base: env.WEBDAV_BASE.replace(/\/+$/, ''),
    authorization: `Basic ${base64(utf8(`${env.WEBDAV_USER}:${env.WEBDAV_PASS}`))}`,
  };
}

export function davRequest(
  env: Env,
  path: string,
  init?: RequestInit & { timeoutMs?: number },
): Promise<Response> {
  const { base, authorization } = davBase(env);
  const headers = new Headers(init?.headers);
  headers.set('authorization', authorization);
  const { timeoutMs, ...requestInit } = init ?? {};
  if (!timeoutMs) {
    return fetch(`${base}/${encodePath(path)}`, { ...requestInit, headers, redirect: 'follow' });
  }
  // 上游挂死（TCP 建连/响应黑洞）时 fetch 可能永不落定——下载代理的并发槽
  // 因此永不释放，后续请求在 withSlot 里无限轮询。用 AbortController 兜底。
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(`${base}/${encodePath(path)}`, {
    ...requestInit,
    headers,
    signal: controller.signal,
    redirect: 'follow',
  }).finally(() => clearTimeout(timer));
}

export async function propfind(env: Env, path: string, depth: '0' | '1'): Promise<DavEntry[]> {
  const response = await davRequest(env, path, {
    method: 'PROPFIND',
    headers: { depth, 'content-type': 'application/xml; charset=utf-8' },
    body: PROPFIND_BODY,
    timeoutMs: 30_000,
  });
  if (response.status !== 207) {
    await response.body?.cancel();
    throw new DavError(response.status);
  }
  // 只返回“子项”。WebDAV 的 207 响应里始终含被 PROPFIND 的目录自身；
  // 之前没过滤掉它，sync 把 packages/ 当成一个包、又把包目录当成版本目录
  // 重复列目录，几十次子请求在扫到第一个真实包前就耗尽 50 次免费额度。
  const selfPath = path.replace(/^\/+|\/+$/g, '');
  return parseMultiStatus(await response.text(), env).filter(
    (entry) => entry.path !== selfPath,
  );
}

/**
 * Range 读取一小段字节（只用于 ZIP 中央目录与 manifest，不用于整文件）。
 *
 * 关键：必须显式 `Accept-Encoding: identity`。Workers 的 fetch 默认会带
 * `Accept-Encoding: gzip`，Teracloud(Apache) 见到 gzip 就会忽略 Range、返回
 * 整文件的 200 + gzip（实测：带 gzip 头 → 200，带 identity → 206 正常）。
 * 后果：非 0 起点的 Range 拿到 200 被判失败；从 0 起点拿到整文件自动解压后
 * 字节与 Content-Range 错位，抠出来的 manifest 数据错乱、解压报
 * "Gzip decompression failed"。显式 identity 让 Range 真正生效。
 *
 * 服务器确实忽略 Range 返回 200 时，只有从 0 开始才当整文件读；其余降级为
 * 下载整文件后本地切片（兼容那些完全不支持 Range 的服务器，代价是内存）。
 */
export async function davRead(
  env: Env,
  path: string,
  start: number,
  endInclusive: number,
): Promise<Uint8Array> {
  const response = await davRequest(env, path, {
    method: 'GET',
    headers: {
      range: `bytes=${start}-${endInclusive}`,
      'accept-encoding': 'identity',
    },
    timeoutMs: 30_000,
  });
  if (response.status === 206) return new Uint8Array(await response.arrayBuffer());
  if (response.status === 200 && start === 0) return new Uint8Array(await response.arrayBuffer());
  if (response.status === 200) {
    // 服务器忽略了 Range：整文件下载后切片。注意 whole 可能较大，
    // 但这只发生在不支持 Range 的服务器上，属兼容性兜底路径。
    const whole = new Uint8Array(await response.arrayBuffer());
    return whole.slice(start, endInclusive + 1);
  }
  await response.body?.cancel();
  throw new DavError(response.status);
}

function xmlUnescape(value: string): string {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(Number(code)))
    .replace(/&amp;/g, '&');
}

function pickTag(block: string, tag: string): string | null {
  const pattern = new RegExp(
    `<(?:[A-Za-z0-9_-]+:)?${tag}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tag}>`,
    'i',
  );
  const match = pattern.exec(block);
  if (!match || match[1] === undefined) return null;
  return xmlUnescape(match[1].trim());
}

/** 路径逐段百分号解码，避免把段内的 %2F 还原成路径分隔符。 */
function decodeSegments(path: string): string {
  return path
    .split('/')
    .map((segment) => {
      try {
        return decodeURIComponent(segment);
      } catch {
        return segment;
      }
    })
    .join('/');
}

/** 解析 207 Multi-Status；跳过授权根自身与 base 之外的 href。 */
export function parseMultiStatus(xml: string, env: Env): DavEntry[] {
  // 与 href 相同的逐段解码：WEBDAV_BASE 含百分号编码（如 %20）时不解的话，
  // 编码的 base 和解码后的 href 做前缀匹配永远失败，所有条目被静默过滤。
  const basePath = decodeSegments(new URL(env.WEBDAV_BASE).pathname.replace(/\/+$/, ''));
  const entries: DavEntry[] = [];

  for (const match of xml.matchAll(RESPONSE_BLOCK)) {
    const block = match[1] ?? '';
    const href = pickTag(block, 'href');
    if (!href) continue;

    let hrefPath: string;
    try {
      hrefPath = new URL(href, 'https://dav.invalid').pathname;
    } catch {
      continue;
    }

    const decoded = decodeSegments(hrefPath);
    const normalized = decoded.replace(/\/+$/, '');
    if (normalized === basePath) continue;
    if (!normalized.startsWith(`${basePath}/`)) continue;

    const relative = normalized.slice(basePath.length + 1);
    if (!relative) continue;

    const sizeText = pickTag(block, 'getcontentlength');
    const modifiedText = pickTag(block, 'getlastmodified');
    const modified = modifiedText ? Date.parse(modifiedText) : Number.NaN;

    entries.push({
      path: relative,
      name: relative.slice(relative.lastIndexOf('/') + 1),
      isDir: COLLECTION_TAG.test(block),
      size: sizeText !== null && /^\d+$/.test(sizeText) ? Number(sizeText) : null,
      lastModified: Number.isFinite(modified) ? modified : null,
    });
  }

  return entries;
}
