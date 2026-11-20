#!/usr/bin/env node
/**
 * 本地联调用的只读 WebDAV 桩（仅开发，不部署）。
 *
 * 用法：
 *   node tool/stub-webdav.mjs .tmp-dav 8799
 *
 * 把目录映射到 /zuno，支持 PROPFIND(Depth 0/1)、GET/HEAD、Range、Basic 认证，
 * 用来在没有真实 WebDAV 的情况下验证同步、票据与断点续传。
 * 账号密码取 WEBDAV_USER / WEBDAV_PASS 环境变量（默认 zuno-reader / dev-pass）。
 */
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';

const rootArg = process.argv[2] ?? '.tmp-dav';
const port = Number(process.argv[3] ?? process.env.PORT ?? 8799);
const basePrefix = '/zuno';
const root = path.resolve(rootArg);
const user = process.env.WEBDAV_USER ?? 'zuno-reader';
const pass = process.env.WEBDAV_PASS ?? 'dev-pass';

const CONTENT_TYPES = new Map([
  ['.zuno', 'application/zip'],
  ['.zip', 'application/zip'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.png', 'image/png'],
]);

function xmlEscape(value) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function authorized(request) {
  const header = request.headers.authorization ?? '';
  if (!header.startsWith('Basic ')) return false;
  const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
  const separator = decoded.indexOf(':');
  if (separator < 0) return false;
  return decoded.slice(0, separator) === user && decoded.slice(separator + 1) === pass;
}

function toFsPath(urlPath) {
  const decoded = urlPath
    .split('/')
    .map((segment) => {
      try {
        return decodeURIComponent(segment);
      } catch {
        return segment;
      }
    })
    .join('/');
  if (decoded !== basePrefix && !decoded.startsWith(`${basePrefix}/`)) return null;
  const segments = decoded.slice(basePrefix.length).split('/').filter(Boolean);
  if (segments.some((segment) => segment === '.' || segment === '..')) return null;
  return path.join(root, ...segments);
}

function hrefFor(fsPath, isDir) {
  const relative = path.relative(root, fsPath).split(path.sep).filter(Boolean).map(encodeURIComponent);
  const suffix = isDir && relative.length > 0 ? '/' : '';
  return `${basePrefix}/${relative.join('/')}${suffix}`;
}

function responseEntry(href, isDir, stat) {
  const resourcetype = isDir ? '<D:collection/>' : '';
  const size = isDir ? '' : `<D:getcontentlength>${stat.size}</D:getcontentlength>`;
  return (
    '<D:response>' +
    `<D:href>${xmlEscape(href)}</D:href>` +
    '<D:propstat><D:prop>' +
    `<D:resourcetype>${resourcetype}</D:resourcetype>` +
    size +
    `<D:getlastmodified>${stat.mtime.toUTCString()}</D:getlastmodified>` +
    '</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>' +
    '</D:response>'
  );
}

async function sendPropfind(request, response, fsPath) {
  const stat = await fsp.stat(fsPath).catch(() => null);
  if (!stat) return sendStatus(response, 404);
  const depth = String(request.headers.depth ?? '0');
  const entries = [responseEntry(hrefFor(fsPath, stat.isDirectory()), stat.isDirectory(), stat)];
  if (stat.isDirectory() && depth !== '0') {
    for (const name of await fsp.readdir(fsPath)) {
      const child = path.join(fsPath, name);
      const childStat = await fsp.stat(child).catch(() => null);
      if (!childStat) continue;
      entries.push(responseEntry(hrefFor(child, childStat.isDirectory()), childStat.isDirectory(), childStat));
    }
  }
  const body =
    '<?xml version="1.0" encoding="utf-8"?>' +
    '<D:multistatus xmlns:D="DAV:">' +
    entries.join('') +
    '</D:multistatus>';
  response.writeHead(207, {
    'content-type': 'application/xml; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });
  response.end(body);
}

function parseRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header ?? '');
  if (!match) return null;
  const [, rawStart, rawEnd] = match;
  if (rawStart === '' && rawEnd === '') return null;
  let start;
  let end;
  if (rawStart === '') {
    start = Math.max(size - Number(rawEnd), 0);
    end = size - 1;
  } else {
    start = Number(rawStart);
    end = rawEnd === '' ? size - 1 : Math.min(Number(rawEnd), size - 1);
  }
  if (!Number.isFinite(start) || !Number.isFinite(end) || start > end || start >= size) return null;
  return { start, end };
}

async function sendFile(request, response, fsPath) {
  const stat = await fsp.stat(fsPath).catch(() => null);
  if (!stat || !stat.isFile()) return sendStatus(response, 404);
  const type = CONTENT_TYPES.get(path.extname(fsPath).toLowerCase()) ?? 'application/octet-stream';
  const range = parseRange(request.headers.range, stat.size);

  if (range) {
    response.writeHead(206, {
      'content-type': type,
      'content-length': range.end - range.start + 1,
      'content-range': `bytes ${range.start}-${range.end}/${stat.size}`,
      'accept-ranges': 'bytes',
      etag: `"${stat.size}-${Number(stat.mtimeMs)}"`,
    });
    if (request.method === 'HEAD') return response.end();
    fs.createReadStream(fsPath, { start: range.start, end: range.end }).pipe(response);
    return;
  }

  response.writeHead(200, {
    'content-type': type,
    'content-length': stat.size,
    'accept-ranges': 'bytes',
    etag: `"${stat.size}-${Number(stat.mtimeMs)}"`,
  });
  if (request.method === 'HEAD') return response.end();
  fs.createReadStream(fsPath).pipe(response);
}

function sendStatus(response, status) {
  response.writeHead(status, { 'content-length': 0 });
  response.end();
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url ?? '/', 'http://stub.invalid');
  if (!authorized(request)) {
    response.writeHead(401, {
      'www-authenticate': 'Basic realm="zuno-stub"',
      'content-length': 0,
    });
    return response.end();
  }

  const fsPath = toFsPath(url.pathname);
  if (!fsPath) return sendStatus(response, 404);

  console.log(`${request.method} ${url.pathname}${request.headers.range ? ` [${request.headers.range}]` : ''}`);

  if (request.method === 'PROPFIND') {
    sendPropfind(request, response, fsPath).catch(() => sendStatus(response, 500));
    return;
  }
  if (request.method === 'GET' || request.method === 'HEAD') {
    sendFile(request, response, fsPath).catch(() => sendStatus(response, 500));
    return;
  }
  sendStatus(response, 405);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`WebDAV 桩已启动：http://127.0.0.1:${port}${basePrefix}（root=${root}）`);
});
