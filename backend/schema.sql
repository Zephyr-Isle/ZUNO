-- 与 docs/backend.md §3 一致：用户、会话、壁纸元数据、下载记录。
-- 初始化：npm run db:init:local / npm run db:init:remote

CREATE TABLE users (
  id            TEXT PRIMARY KEY,
  email         TEXT UNIQUE,
  password_hash TEXT,
  password_salt TEXT,
  created_at    INTEGER NOT NULL
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX idx_sessions_user ON sessions(user_id);

CREATE TABLE wallpapers (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  author      TEXT,
  type        TEXT NOT NULL,          -- video / html / depth / timed
  version     TEXT NOT NULL,
  size        INTEGER NOT NULL,
  webdav_path TEXT NOT NULL,
  cover_path  TEXT,
  updated_at  INTEGER NOT NULL
);
-- 目录接口按 (updated_at DESC, id DESC) keyset 分页，必须有对应索引避免全表排序。
CREATE INDEX idx_wallpapers_updated ON wallpapers(updated_at DESC, id DESC);

CREATE TABLE downloads (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      TEXT NOT NULL,
  wallpaper_id TEXT NOT NULL,
  at           INTEGER NOT NULL
);
CREATE INDEX idx_downloads_user ON downloads(user_id, at);
-- 管理端删除按 wallpaper_id 清下载记录，需要这条索引避免全表扫描。
CREATE INDEX idx_downloads_wallpaper ON downloads(wallpaper_id);
