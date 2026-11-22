//! zuno-api 的 Docker 自托管入口：把 Cloudflare Worker 代码原样跑在 Node 上。
//!
//! `src/` 是纯 fetch handler + 标准 Web API，仅三处依赖 Workers 运行时：
//! 1. `env.DB`（D1 绑定）——这里换成 node:sqlite 的适配器（SQL 是标准
//!    SQLite 方言，schema.sql 原样可用）；
//! 2. `ctx.waitUntil`——shim 成"记录并吞掉异常"；
//! 3. `caches.default`——no-op shim：match 永远 miss，封面代理退化为
//!    每次直连 WebDAV（自托管默认不开 CACHE_DOWNLOADS，行为不受影响）。
//!
//! 构建见 package.json 的 `bundle:selfhost`：esbuild 把本文件连同
//! `src/index.ts` 打成单文件 `selfhost/dist/server.mjs`（schema.sql 以
//! text loader 内联），Dockerfile 直接运行这个产物。

import { mkdirSync } from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { Readable } from 'node:stream';
import type { IncomingMessage, ServerResponse } from 'node:http';
import type { ReadableStream as NodeWebReadableStream } from 'node:stream/web';
import { pipeline } from 'node:stream/promises';
import { DatabaseSync } from 'node:sqlite';
import type { SQLInputValue } from 'node:sqlite';

// Worker 主体与 schema：esbuild 会把它们打进 bundle。
import handler from '../src/index';
import type { Env } from '../src/env';
import schemaSql from '../schema.sql';

// ------------------------------------------------------------- caches shim

type NoopCache = {
  match: (request: Request | string) => Promise<Response | undefined>;
  put: (request: Request | string, response: Response) => Promise<void>;
  delete: (request: Request | string) => Promise<boolean>;
};

const globalScope = globalThis as unknown as Record<string, unknown>;
globalScope.caches ??= {
  default: {
    match: async () => undefined,
    put: async () => undefined,
    delete: async () => false,
  } satisfies NoopCache,
};

// ------------------------------------------------------------------ D1 适配

/** node:sqlite 之上的最小 D1Database 实现：只覆盖 src/ 用到的 prepare/bind/run/first/all。 */
class SqliteDatabase {
  private readonly db: DatabaseSync;

  constructor(dbPath: string) {
    mkdirSync(path.dirname(dbPath), { recursive: true });
    this.db = new DatabaseSync(dbPath);
    // WAL：读写并发不互相阻塞；busy_timeout：偶发锁竞争时等待而非报错。
    this.db.exec('PRAGMA journal_mode = WAL;');
    this.db.exec('PRAGMA busy_timeout = 5000;');
  }

  prepare(sql: string) {
    // D1 语义：prepare() 返回的语句**不带绑定即可执行**（如 health 的
    // `SELECT 1`），bind() 返回绑好参数的新语句。两条路共用同一个
    // StatementSync（node:sqlite 按调用传参绑定，跨调用互不影响）。
    const stmt = this.db.prepare(sql);
    const makeStatement = (bound: SQLInputValue[]) => ({
      /** batch 内部使用：以当前绑定参数同步执行（每条语句各自覆盖）。 */
      _exec: () => {
        stmt.run(...bound);
      },
      run: async () => {
        stmt.run(...bound);
        return { success: true as const, meta: {} };
      },
      first: async <T>() => (stmt.get(...bound) as T | undefined) ?? null,
      all: async <T>() => ({ results: stmt.all(...bound) as T[] }),
    });
    // node:sqlite 只接受 null/number/bigint/string/Buffer；Worker 代码
    // 只绑这几种，布尔值保险起见转成 0/1。
    const toSql = (p: unknown): SQLInputValue =>
      typeof p === 'boolean'
        ? p
          ? 1
          : 0
        : p === undefined
          ? null
          : (p as SQLInputValue);
    return {
      ...makeStatement([]),
      bind: (...params: unknown[]) => makeStatement(params.map(toSql)),
    };
  }

  /** D1Database.batch 的最小实现：单事务顺序执行，任一失败整体回滚。 */
  batch(statements: Array<{ _exec: () => void }>): Promise<unknown[]> {
    this.db.exec('BEGIN');
    try {
      const results = statements.map((statement) => statement._exec());
      this.db.exec('COMMIT');
      return Promise.resolve(results);
    } catch (error) {
      this.db.exec('ROLLBACK');
      return Promise.reject(error);
    }
  }

  exec(sql: string): void {
    this.db.exec(sql);
  }

  close(): void {
    this.db.close();
  }
}

const dbPath = process.env.DB_PATH ?? path.join('data', 'zuno.db');
const sqlite = new SqliteDatabase(dbPath);

// 首次启动自动建表：schema.sql 是幂等的 DDL（sqlite_master 判空后才执行）。
const hasSchema = await sqlite
  .prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'wallpapers'",
  )
  .bind()
  .first<{ name: string }>();
if (hasSchema === null) {
  console.log(`数据库为空，初始化 schema：${dbPath}`);
  sqlite.exec(schemaSql);
}

// -------------------------------------------------------------------- 环境

const env: Env = {
  DB: sqlite as unknown as Env['DB'],
  WEBDAV_BASE: process.env.WEBDAV_BASE ?? '',
  WEBDAV_USER: process.env.WEBDAV_USER ?? '',
  WEBDAV_PASS: process.env.WEBDAV_PASS ?? '',
  TICKET_SECRET: process.env.TICKET_SECRET ?? '',
  ADMIN_SECRET: process.env.ADMIN_SECRET ?? '',
  PBKDF2_ITERATIONS: process.env.PBKDF2_ITERATIONS,
  DOWNLOAD_CONCURRENCY: process.env.DOWNLOAD_CONCURRENCY,
  CACHE_DOWNLOADS: process.env.CACHE_DOWNLOADS,
};

// 缺配置不阻断启动：/health 仍可用，相关接口按 Worker 原逻辑返回
// server_misconfigured（带缺失项清单），便于对着日志补环境变量。
const requiredKeys = [
  'WEBDAV_BASE',
  'WEBDAV_USER',
  'WEBDAV_PASS',
  'TICKET_SECRET',
  'ADMIN_SECRET',
] as const;
const missing = requiredKeys.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.warn(`缺少配置 ${missing.join(', ')}：相关接口会返回 server_misconfigured`);
}

// shim 的最小实现就够 src/ 使用；ExecutionContext 的其余成员
// （exports/tracing 等）Workers 专有，自托管不会触达，断言收敛。
const ctx = {
  waitUntil(promise: Promise<unknown>): void {
    // Worker 里 waitUntil 是"响应返回后继续跑完"的后台任务（记下载、
    // 缓存清理）。单进程 Node 直接 await 也不影响响应，这里保持语义：
    // 不阻塞，只捕获异常打日志。
    Promise.resolve(promise).catch((error) => {
      console.error('[waitUntil] 后台任务失败', error);
    });
  },
  passThroughOnException(): void {
    // Workers 专有（跨宿主转发），自托管下无意义。
  },
} as unknown as ExecutionContext;

// ------------------------------------------------------------- HTTP 转换

/** 逐跳头不透传给 Request（content-length 交给 Request 按 body 重算）。 */
const HOP_HEADERS = new Set([
  'connection',
  'keep-alive',
  'transfer-encoding',
  'upgrade',
  'content-length',
  'host',
]);

/** POST 的 body 都是 ≤16KB 的 JSON（readJsonObject 自带上限），这里整体缓冲。 */
const MAX_BODY_BYTES = 1 << 20;

function readBody(req: IncomingMessage): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let total = 0;
    req.on('data', (chunk: Buffer) => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        reject(new Error('request body too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function writeResponse(res: ServerResponse, response: Response): Promise<void> {
  const headers: Record<string, string> = {};
  response.headers.forEach((value, name) => {
    headers[name] = value;
  });
  res.writeHead(response.status, headers);
  if (response.body === null) {
    res.end();
    return;
  }
  await pipeline(
    Readable.fromWeb(response.body as unknown as NodeWebReadableStream),
    res,
  );
}

const port = Number(process.env.PORT ?? '8080');

const server = http.createServer(async (req, res) => {
  try {
    const host = req.headers.host ?? `127.0.0.1:${port}`;
    const url = new URL(req.url ?? '/', `http://${host}`).toString();
    const method = (req.method ?? 'GET').toUpperCase();
    const headers = new Headers();
    for (const [name, value] of Object.entries(req.headers)) {
      if (value === undefined || HOP_HEADERS.has(name)) continue;
      if (Array.isArray(value)) {
        for (const item of value) headers.append(name, item);
      } else {
        headers.set(name, value);
      }
    }
    const hasBody = method !== 'GET' && method !== 'HEAD';
    const body = hasBody ? await readBody(req) : undefined;
    const request = new Request(url, {
      method,
      headers,
      ...(body === undefined ? {} : { body }),
    });
    const response = await handler.fetch(request, env, ctx);
    await writeResponse(res, response);
  } catch (error) {
    console.error('请求处理失败', error);
    if (res.headersSent) {
      res.destroy();
      return;
    }
    res.writeHead(500, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'internal_error', message: '服务器内部错误' }));
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`zuno-api (selfhost) listening on 0.0.0.0:${port}`);
  console.log(`数据库：${dbPath}`);
});

// 端口被占（重复容器/已有实例）时 Node 会发未处理的 'error' 事件并带原始
// 堆栈崩溃——在 Docker 里表现为无意义的 crash-loop。这里给出明确原因退出。
server.on('error', (error) => {
  console.error('zuno-api 自托管服务器启动失败', error);
  process.exit(1);
});

// docker stop / Ctrl-C 时优雅退出：停止接新请求并断开 keep-alive 空闲连接；
// close 回调在活动请求（含流式下载与 waitUntil 后台任务）全部结束后触发，
// 届时才关数据库——过早 close 会让在途写库丢失、下载被截断。3 秒硬超时
// 兜底：超时放弃优雅收尾直接退出（客户端的 checksum/导入层会兜住半截文件）。
let shuttingDown = false;
function shutdown(): void {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('收到退出信号，正在关闭…');
  server.closeIdleConnections?.();
  server.close(() => {
    try {
      sqlite.close();
    } catch (error) {
      console.error('关闭数据库失败', error);
    }
    process.exit(0);
  });
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
