/**
 * POST /api/admin/sync：扫描 `/zuno/packages/<id>/<version>/*.zuno`，
 * 用 manifest 旁车文件（优先）或三次 Range 请求读出包内 manifest.json，
 * 再把元数据 upsert 进 D1。
 *
 * 免费版单次请求只有 50 次子请求，所以同步支持两种模式：
 * - `?id=<manifest.id>` 只同步一个包（管理端每次上传后调用，约 5–10 次子请求）；
 * - `?offset=N&limit=M` 批量扫描，按 WebDAV 修改时间从新到旧，返回 `nextOffset`
 *   供调用方续扫。单次最多 20 个包目录，默认 5 个。
 */
import type { Env } from './env';
import { fail, json, requireConfig, timingSafeEqual, utf8 } from './http';
import { davRequest, DavError, propfind, type DavEntry } from './webdav';
import { readManifestFromWebdav } from './zip';

const WALLPAPER_TYPES = new Set(['video', 'html', 'depth', 'timed']);
const DEFAULT_LIMIT = 5;
const MAX_PACKAGE_DIRS = 20;
const MAX_REPORTED_SKIPS = 50;
const ID_PATTERN = /^[A-Za-z0-9_.-]{1,200}$/;

interface SyncRecord {
  id: string;
  title: string;
  author: string | null;
  type: string;
  version: string;
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/** 子请求额度耗尽：继续扫只会得到一串同样的错误，应立即停下并交回续扫偏移。 */
function isBudgetError(error: unknown): boolean {
  return /too many subrequests/i.test(describe(error));
}

function toRecord(
  manifest: Record<string, unknown> | null,
  packageId: string,
  versionDirName: string,
): SyncRecord | null {
  if (!manifest) return null;

  const id = typeof manifest.id === 'string' && manifest.id.length > 0 ? manifest.id : packageId;
  const type = typeof manifest.type === 'string' ? manifest.type : '';
  if (!WALLPAPER_TYPES.has(type)) return null;

  const title =
    typeof manifest.title === 'string' && manifest.title.length > 0 ? manifest.title : id;
  const version =
    typeof manifest.version === 'string' && manifest.version.length > 0
      ? manifest.version
      : versionDirName;

  const authorRecord =
    manifest.author && typeof manifest.author === 'object'
      ? (manifest.author as Record<string, unknown>)
      : null;
  const author =
    typeof authorRecord?.handle === 'string'
      ? authorRecord.handle
      : typeof authorRecord?.id === 'string'
        ? authorRecord.id
        : null;

  if (id.length > 200 || title.length > 200) return null;
  return { id, title, author, type, version };
}

/**
 * 读版本目录下的 manifest.json 旁车文件（普通 GET，无 Range）。
 * 管理端上传包时会同时放一份；优先用它，彻底绕开从 ZIP 抠 manifest 时
 * WebDAV 服务器对 gzip+Range 的兼容坑。读不到返回 null，由调用方回退。
 */
async function readManifestSidecar(
  env: Env,
  versionDirPath: string,
): Promise<Record<string, unknown> | null> {
  try {
    const response = await davRequest(env, `${versionDirPath}/manifest.json`, {
      method: 'GET',
      headers: { 'accept-encoding': 'identity' },
    });
    if (response.status !== 200) {
      await response.body?.cancel();
      return null;
    }
    const parsed: unknown = JSON.parse(await response.text());
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}

async function listCovers(env: Env): Promise<Map<string, string>> {
  const covers = new Map<string, string>();
  try {
    for (const entry of await propfind(env, 'covers', '1')) {
      if (entry.isDir) continue;
      const id = entry.name.replace(/\.[^.]+$/, '');
      if (id) covers.set(id, entry.path);
    }
  } catch (error) {
    if (!(error instanceof DavError && error.status === 404)) {
      console.warn('封面目录扫描失败', error);
    }
  }
  return covers;
}

function readInt(raw: string | null, fallback: number, min: number, max: number): number {
  if (raw === null || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value)) return fallback;
  return Math.min(Math.max(Math.trunc(value), min), max);
}

export async function handleAdminSync(request: Request, env: Env): Promise<Response> {
  requireConfig(env, ['ADMIN_SECRET']);
  const provided = request.headers.get('x-admin-secret') ?? '';
  if (!timingSafeEqual(utf8(provided), utf8(env.ADMIN_SECRET))) {
    return fail(403, 'forbidden', 'Admin Secret 不正确');
  }

  const url = new URL(request.url);
  const rawId = (url.searchParams.get('id') ?? '').trim();
  if (rawId && (!ID_PATTERN.test(rawId) || rawId === '.' || rawId === '..')) {
    return fail(400, 'invalid_id', 'id 只能包含字母、数字、点、下划线和短横线');
  }
  const offset = readInt(url.searchParams.get('offset'), 0, 0, 100_000);
  const limit = readInt(url.searchParams.get('limit'), DEFAULT_LIMIT, 1, MAX_PACKAGE_DIRS);

  const startedAt = Date.now();
  const covers = await listCovers(env);
  const skipped: { path: string; reason: string }[] = [];
  let scanned = 0;
  let upserted = 0;
  let nextOffset: number | null = null;

  // 单个包模式：不列 packages/，直接列 packages/<id>/ 下的版本目录。
  let packageDirs: DavEntry[];
  if (rawId) {
    try {
      packageDirs = (await propfind(env, `packages/${rawId}`, '1')).filter((entry) => entry.isDir);
    } catch (error) {
      if (error instanceof DavError && error.status === 404) {
        return fail(404, 'package_not_found', `WebDAV 上不存在 packages/${rawId}/`);
      }
      return fail(502, 'webdav_unavailable', `无法读取 WebDAV 目录（${describe(error)}）`);
    }
    if (packageDirs.length === 0) {
      return fail(404, 'package_not_found', `packages/${rawId}/ 下没有版本目录`);
    }
  } else {
    let all: DavEntry[];
    try {
      all = (await propfind(env, 'packages', '1')).filter((entry) => entry.isDir);
    } catch (error) {
      return fail(502, 'webdav_unavailable', `无法读取 WebDAV 目录（${describe(error)}）`);
    }
    // 新上传的包优先：管理端上传后会立刻同步，旧包留到后续 offset 再扫。
    all.sort((a, b) => (b.lastModified ?? 0) - (a.lastModified ?? 0) || a.path.localeCompare(b.path));
    packageDirs = all.slice(offset, offset + limit);
    nextOffset = offset + packageDirs.length < all.length ? offset + packageDirs.length : null;
  }

  const scanVersionDirs = async (packageName: string, versions: DavEntry[]): Promise<void> => {
    for (const versionDir of versions) {
      let files: DavEntry[];
      try {
        // README §2：.zuno 与 .zip 都是合法 ZIP 容器，两种都要收录。
        files = (await propfind(env, versionDir.path, '1')).filter(
          (entry) =>
            !entry.isDir &&
            (entry.name.toLowerCase().endsWith('.zuno') ||
              entry.name.toLowerCase().endsWith('.zip')),
        );
      } catch (error) {
        if (isBudgetError(error)) throw error;
        skipped.push({ path: versionDir.path, reason: describe(error) });
        continue;
      }
      if (files.length === 0) continue;

      // 优先读旁车 manifest（一次普通 GET），读不到才回退到 Range 抠 ZIP。
      const sidecar = await readManifestSidecar(env, versionDir.path);

      for (const file of files) {
        scanned += 1;
        try {
          const manifest =
            sidecar ?? (await readManifestFromWebdav(env, file.path, file.size ?? 0));
          const record = toRecord(manifest, packageName, versionDir.name);
          if (!record) {
            skipped.push({ path: file.path, reason: '无法从 .zuno 中读出合法 manifest' });
            continue;
          }
          await env.DB.prepare(
            'INSERT INTO wallpapers ' +
              '(id, title, author, type, version, size, webdav_path, cover_path, updated_at) ' +
              'VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9) ' +
              'ON CONFLICT(id) DO UPDATE SET ' +
              'title = excluded.title, author = excluded.author, type = excluded.type, ' +
              'version = excluded.version, size = excluded.size, ' +
              'webdav_path = excluded.webdav_path, cover_path = excluded.cover_path, ' +
              'updated_at = excluded.updated_at',
          )
            .bind(
              record.id,
              record.title,
              record.author,
              record.type,
              record.version,
              file.size ?? 0,
              file.path,
              covers.get(record.id) ?? null,
              file.lastModified ?? Date.now(),
            )
            .run();
          // 版本/文件路径变化时清除该壁纸的整文件下载缓存（download.ts 开启
          // CACHE_DOWNLOADS 后按 id 缓存且 max-age=3600）。统一清一次最简单：
          // 同步本来就不频繁，缓存失配的代价远大于一次本地 cache 删除。
          try {
            await caches.default.delete(
              new Request(
                new URL(
                  `/download/${encodeURIComponent(record.id)}`,
                  new URL(request.url).origin,
                ).toString(),
                { method: 'GET' },
              ),
            );
          } catch {
            // 缓存清除失败不影响收录（TTL 一小时后自然过期）。
          }
          // 封面同样是按 id 缓存 1 小时（wallpapers.ts handleCover）。换封面
          // 不会改变包路径，不清缓存的话管理端上传完仍会看到旧图。
          try {
            await caches.default.delete(
              new Request(
                new URL(
                  `/api/wallpapers/${encodeURIComponent(record.id)}/cover`,
                  new URL(request.url).origin,
                ).toString(),
                { method: 'GET' },
              ),
            );
          } catch {
            // 同上。
          }
          upserted += 1;
        } catch (error) {
          if (isBudgetError(error)) throw error;
          skipped.push({ path: file.path, reason: describe(error) });
        }
      }
    }
  };

  if (rawId) {
    // packageDirs 在单包模式下就是 packages/<id>/ 的子目录（版本目录）。
    try {
      await scanVersionDirs(rawId, packageDirs);
    } catch (error) {
      if (!isBudgetError(error)) {
        skipped.push({ path: `packages/${rawId}`, reason: describe(error) });
      }
    }
    return json({
      mode: 'single',
      scanned,
      upserted,
      covers: covers.size,
      skipped: skipped.slice(0, MAX_REPORTED_SKIPS),
      nextOffset: null,
      durationMs: Date.now() - startedAt,
    });
  }

  for (let index = 0; index < packageDirs.length; index += 1) {
    const packageDir = packageDirs[index]!;
    try {
      const versions = (await propfind(env, packageDir.path, '1')).filter(
        (entry) => entry.isDir,
      );
      if (versions.length > 0) await scanVersionDirs(packageDir.name, versions);
    } catch (error) {
      if (isBudgetError(error)) {
        // 这个包还没扫完，下次从它开始；已收录的条目不会回滚。
        nextOffset = offset + index;
        break;
      }
      skipped.push({ path: packageDir.path, reason: describe(error) });
    }
  }

  return json({
    mode: 'bulk',
    scanned,
    upserted,
    covers: covers.size,
    skipped: skipped.slice(0, MAX_REPORTED_SKIPS),
    nextOffset,
    durationMs: Date.now() - startedAt,
  });
}
