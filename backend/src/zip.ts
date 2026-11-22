/**
 * 只读 ZIP 的 `manifest.json`：三次 Range 请求（EOCD 尾段、中央目录、manifest 数据），
 * 不把几十 MB 的包拉进 Worker（内存 128MB）。
 *
 * 只支持 store(0) / deflate(8)、非 ZIP64——.zuno 由 tool/create_sample_packages.dart
 * 生成，满足这些条件；其它情况返回 null，由同步报告 skipped。
 */
import type { Env } from './env';
import { davRead, DavError } from './webdav';

const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_SIGNATURE = 0x02014b50;
const MAX_CENTRAL_DIR = 4 * 1024 * 1024;
const MAX_MANIFEST_BYTES = 512 * 1024;
const TAIL_BYTES = 66_000;
/**
 * Workers 的 fetch 子请求会剥掉 Range（实测上游永远收到整文件 GET），
 * 所以三次 Range 实际是三次整文件下载。超过这个大小就不猜了，
 * 让 sync 带着明确原因跳过，由管理端补 manifest.json 旁车。
 */
const MAX_FULL_SCAN_BYTES = 16 * 1024 * 1024;

function u16(bytes: Uint8Array, offset: number): number {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

function u32(bytes: Uint8Array, offset: number): number {
  return (
    (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)) >>> 0
  );
}

async function inflateRaw(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

export async function readManifestFromWebdav(
  env: Env,
  path: string,
  size: number,
): Promise<Record<string, unknown> | null> {
  if (!Number.isFinite(size) || size < 22) return null;
  if (size > MAX_FULL_SCAN_BYTES) {
    console.warn(`包体积 ${size} 超过 ${MAX_FULL_SCAN_BYTES}，缺少 manifest.json 旁车，跳过`);
    return null;
  }

  // 1) EOCD 必须在文件末尾 65557 字节内（注释最长 64KB）。
  const tailLength = Math.min(size, TAIL_BYTES);
  const tailStart = size - tailLength;
  const tail = await davRead(env, path, tailStart, size - 1);
  let eocd = -1;
  for (let i = tail.length - 22; i >= 0; i -= 1) {
    if (u32(tail, i) === EOCD_SIGNATURE) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) return null;

  const entryCount = u16(tail, eocd + 10);
  const centralSize = u32(tail, eocd + 12);
  const centralOffset = u32(tail, eocd + 16);
  if (entryCount === 0xffff || centralSize === 0xffffffff || centralOffset === 0xffffffff) {
    return null;
  }
  if (centralSize === 0 || centralSize > MAX_CENTRAL_DIR) return null;

  // 2) 中央目录：找到 manifest.json 的压缩方式、大小与本地头偏移。
  const central = await davRead(env, path, centralOffset, centralOffset + centralSize - 1);
  let cursor = 0;
  let target: { method: number; compressedSize: number; localOffset: number } | null = null;
  for (let index = 0; index < entryCount && cursor + 46 <= central.length; index += 1) {
    if (u32(central, cursor) !== CENTRAL_SIGNATURE) break;
    const method = u16(central, cursor + 10);
    const compressedSize = u32(central, cursor + 20);
    const nameLength = u16(central, cursor + 28);
    const extraLength = u16(central, cursor + 30);
    const commentLength = u16(central, cursor + 32);
    const localOffset = u32(central, cursor + 42);
    const nameBytes = central.subarray(cursor + 46, cursor + 46 + nameLength);
    const name = new TextDecoder().decode(nameBytes);

    // 根目录或单一顶层文件夹内的 manifest.json（internal-docs/docs/package-format.md 允许两种布局）。
    const isManifest = name === 'manifest.json' || /^[^/]+\/manifest\.json$/.test(name);
    if (
      isManifest &&
      (method === 0 || method === 8) &&
      compressedSize > 0 &&
      compressedSize <= MAX_MANIFEST_BYTES
    ) {
      target = { method, compressedSize, localOffset };
      break;
    }
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  if (!target) return null;

  // 3) 本地头给出可变长度的文件名/扩展字段，据此算出数据起点。
  const local = await davRead(env, path, target.localOffset, target.localOffset + 29);
  const localNameLength = u16(local, 26);
  const localExtraLength = u16(local, 28);
  const dataStart = target.localOffset + 30 + localNameLength + localExtraLength;
  const raw = await davRead(env, path, dataStart, dataStart + target.compressedSize - 1);
  const bytes = target.method === 0 ? raw : await inflateRaw(raw);

  try {
    const parsed: unknown = JSON.parse(new TextDecoder().decode(bytes));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

export { DavError };
