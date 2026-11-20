import "./styles.css";
import { convertFileSrc, invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { open, save } from "@tauri-apps/plugin-dialog";

interface Config {
  apiBase: string;
  adminSecret: string;
  webdavBase: string;
  webdavUser: string;
  webdavPass: string;
  localDir: string;
}
interface Wallpaper {
  id: string;
  title: string;
  author?: string | null;
  type: string;
  version: string;
  size: number;
  updatedAt: number;
}
interface PackInfo {
  path: string;
  id: string;
  title: string;
  type: string;
  version: string;
  size: number;
  checksum?: string | null;
  entry?: string | null;
}
interface PreviewInfo {
  path: string;
  type: string;
  title: string;
  manifest: Record<string, unknown>;
  extractedDir: string;
  thumbnail?: string | null;
  entry?: string | null;
  files: string[];
}
interface Progress {
  stage: string;
  message: string;
  value: number;
}

type TabName = "cloud" | "local" | "settings";

const $ = <T extends HTMLElement>(selector: string): T =>
  document.querySelector(selector) as T;
const esc = (value: string): string =>
  value.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] ?? c,
  );
const size = (bytes: number): string =>
  bytes > 1024 * 1024
    ? `${(bytes / 1024 / 1024).toFixed(1)} MB`
    : `${Math.max(1, Math.round(bytes / 1024))} KB`;

const app = $("#app");
app.innerHTML = `
  <div class="app">
    <aside class="sidebar">
      <div class="brand">ZUNO <span>管理端</span></div>
      <button class="nav active" data-tab="cloud">云端壁纸</button>
      <button class="nav" data-tab="local">本地文件</button>
      <button class="nav" data-tab="settings">设置</button>
      <div class="spacer"></div>
      <div class="status">
        <div id="status-text">就绪</div>
        <div class="progress"><i id="status-bar"></i></div>
      </div>
    </aside>
    <main>
      <header>
        <h1 id="page-title">云端壁纸</h1>
        <div class="actions" id="page-actions"></div>
      </header>
      <section class="tab active" id="tab-cloud"></section>
      <section class="tab" id="tab-local"></section>
      <section class="tab" id="tab-settings"></section>
    </main>
  </div>
  <div class="modal hidden" id="preview-modal">
    <div class="modal-body">
      <div class="modal-head">
        <h2 id="preview-title">预览</h2>
        <button class="btn small" id="preview-close">关闭</button>
      </div>
      <div id="preview-view"></div>
    </div>
  </div>
  <div class="toast hidden" id="toast"></div>
`;

let config: Config = {
  apiBase: "https://zuno-api.zephyrisle.qzz.io",
  adminSecret: "",
  webdavBase: "",
  webdavUser: "",
  webdavPass: "",
  localDir: "",
};
let cloud: Wallpaper[] = [];
let locals: PackInfo[] = [];
let tab: TabName = "cloud";
let toastTimer: number | undefined;

function toast(message: string): void {
  const node = $("#toast");
  node.textContent = message;
  node.classList.remove("hidden");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => node.classList.add("hidden"), 3200);
}

function status(stage: string, message: string, value: number): void {
  $("#status-text").textContent = `${stage}：${message}`;
  $("#status-bar").style.width = `${Math.round(Math.min(1, Math.max(0, value)) * 100)}%`;
}

async function run<T>(action: () => Promise<T>): Promise<T | undefined> {
  try {
    return await action();
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    status("错误", message.slice(0, 120), 0);
    toast(message.slice(0, 160));
    return undefined;
  }
}

function switchTab(next: TabName): void {
  tab = next;
  document.querySelectorAll<HTMLButtonElement>(".nav").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === next);
  });
  document.querySelectorAll<HTMLElement>(".tab").forEach((section) => {
    section.classList.toggle("active", section.id === `tab-${next}`);
  });
  const titles: Record<TabName, string> = {
    cloud: "云端壁纸",
    local: "本地文件",
    settings: "设置",
  };
  $("#page-title").textContent = titles[next];
  renderActions();
}

function renderActions(): void {
  const actions = $("#page-actions");
  if (tab === "cloud") {
    actions.innerHTML = `
      <button class="btn" id="act-health">测试连接</button>
      <button class="btn" id="act-sync">同步目录</button>
      <button class="btn primary" id="act-refresh-cloud">刷新列表</button>`;
    $("#act-health").onclick = () =>
      run(async () => {
        const result = await invoke("health", { config });
        status("连接", "API 正常", 1);
        toast(`API 正常：${JSON.stringify(result)}`);
      });
    $("#act-sync").onclick = () =>
      run(async () => {
        const result = await invoke<Record<string, unknown>>("sync_catalog", { config, limit: 5 });
        toast(`同步完成：收录 ${result.upserted ?? 0} 条`);
        await refreshCloud();
      });
    $("#act-refresh-cloud").onclick = () => run(refreshCloud);
  } else if (tab === "local") {
    actions.innerHTML = `
      <button class="btn" id="act-pick-dir">选择目录</button>
      <button class="btn primary" id="act-pack">从源目录打包</button>`;
    $("#act-pick-dir").onclick = () => run(pickLocalDir);
    $("#act-pack").onclick = () => run(packFlow);
  } else {
    actions.innerHTML = "";
  }
}

async function refreshCloud(): Promise<void> {
  cloud = await invoke<Wallpaper[]>("list_wallpapers", { config });
  const root = $("#tab-cloud");
  if (cloud.length === 0) {
    root.innerHTML = `<div class="empty">云端壁纸库是空的。<br><br>先在本地打包上传，再点「同步目录」。</div>`;
    return;
  }
  root.innerHTML = `<div class="grid">${cloud
    .map(
      (item) => `
      <div class="card">
        <span class="badge">${esc(item.type)}</span>
        <h3>${esc(item.title)}</h3>
        <div class="meta">${esc(item.id)}<br>v${esc(item.version)} · ${size(item.size)}<br>${esc(item.author || "未知作者")}</div>
        <div class="row">
          <button class="btn small" data-preview="${esc(item.id)}">预览</button>
          <button class="btn small danger" data-delete="${esc(item.id)}">删除</button>
        </div>
      </div>`,
    )
    .join("")}</div>`;
  root.querySelectorAll<HTMLButtonElement>("[data-preview]").forEach((button) => {
    button.onclick = () =>
      run(async () => {
        const info = await invoke<PreviewInfo>("preview_remote", { config, id: button.dataset.preview });
        showPreview(info);
      });
  });
  root.querySelectorAll<HTMLButtonElement>("[data-delete]").forEach((button) => {
    button.onclick = () => {
      const id = button.dataset.delete ?? "";
      if (!window.confirm(`确定删除云端壁纸「${id}」？包和封面会一起从 WebDAV 删除。`)) return;
      run(async () => {
        await invoke("delete_wallpaper", { config, id, version: cloud.find((item) => item.id === id)?.version ?? "" });
        toast("已删除");
        await refreshCloud();
      });
    };
  });
}

async function pickLocalDir(): Promise<void> {
  const picked = await open({ directory: true, multiple: false, title: "选择本地壁纸目录" });
  if (typeof picked !== "string") return;
  config.localDir = picked;
  await invoke("save_config", { config });
  await refreshLocal();
}

async function refreshLocal(): Promise<void> {
  const root = $("#tab-local");
  if (!config.localDir) {
    root.innerHTML = `<div class="empty">还没有选择本地目录。<br><br>点右上角「选择目录」来列出 .zuno / .zip 文件。</div>`;
    return;
  }
  locals = await invoke<PackInfo[]>("list_packages", { dir: config.localDir });
  if (locals.length === 0) {
    root.innerHTML = `<div class="empty">这个目录里没有 .zuno / .zip 文件。</div>`;
    return;
  }
  root.innerHTML = `<div class="grid">${locals
    .map(
      (item, index) => `
      <div class="card">
        <span class="badge">${esc(item.type)}</span>
        <h3>${esc(item.title)}</h3>
        <div class="meta">${esc(item.path.split(/[\\/]/).pop() ?? "")}<br>v${esc(item.version)} · ${size(item.size)}<br>${esc(item.checksum ? "checksum ✓" : "checksum 缺失")}</div>
        <div class="row">
          <button class="btn small" data-local-preview="${index}">预览</button>
          <button class="btn small" data-local-upload="${index}">上传</button>
          <button class="btn small danger" data-local-delete="${index}">删除</button>
        </div>
      </div>`,
    )
    .join("")}</div>`;
  root.querySelectorAll<HTMLButtonElement>("[data-local-preview]").forEach((button) => {
    button.onclick = () =>
      run(async () => {
        const item = locals[Number(button.dataset.localPreview)];
        if (!item) return;
        showPreview(await invoke<PreviewInfo>("preview_package", { path: item.path }));
      });
  });
  root.querySelectorAll<HTMLButtonElement>("[data-local-upload]").forEach((button) => {
    button.onclick = () => {
      const item = locals[Number(button.dataset.localUpload)];
      if (item) run(() => uploadFlow(item.path));
    };
  });
  root.querySelectorAll<HTMLButtonElement>("[data-local-delete]").forEach((button) => {
    button.onclick = () => {
      const item = locals[Number(button.dataset.localDelete)];
      if (!item) return;
      if (!window.confirm(`删除本地文件「${item.path}」？此操作不可恢复。`)) return;
      run(async () => {
        await invoke("delete_local_package", { path: item.path, localDir: config.localDir });
        toast("已删除本地文件");
        await refreshLocal();
      });
    };
  });
}

async function uploadFlow(path: string): Promise<void> {
  const cover = await open({
    multiple: false,
    title: "选择封面图片（可取消，取消则自动用包内预览图）",
    filters: [{ name: "封面", extensions: ["jpg", "jpeg", "png"] }],
  });
  const result = await invoke<{ sync: Record<string, unknown> }>("upload_package", {
    config,
    packagePath: path,
    coverPath: typeof cover === "string" ? cover : null,
    syncLimit: 5,
  });
  toast(`上传完成，收录 ${result.sync.upserted ?? 0} 条`);
  await refreshCloud();
}

async function packFlow(): Promise<void> {
  const source = await open({
    directory: true,
    multiple: false,
    title: "选择壁纸源目录（内含 manifest.json 与 content/）",
  });
  if (typeof source !== "string") return;
  const target = await save({
    title: "保存压缩包",
    defaultPath: "wallpaper.zuno",
    filters: [{ name: "ZUNO 壁纸包", extensions: ["zuno", "zip"] }],
  });
  if (!target) return;
  const info = await invoke<PackInfo>("pack_directory", { source, output: target });
  status("打包", `${info.title} v${info.version} 已生成`, 1);
  toast(`已生成 ${info.path.split(/[\\/]/).pop() ?? ""}`);
  if (window.confirm("压缩包已生成。是否立即上传并同步？")) {
    await run(() => uploadFlow(info.path));
  }
  if (config.localDir) await refreshLocal();
}

function showPreview(info: PreviewInfo): void {
  const ext = (info.entry ?? "").split(".").pop()?.toLowerCase() ?? "";
  // entry/缩略图路径来自远端包（manifest 与 ZIP 条目名都是第三方可控），
  // convertFileSrc 输出必须转义后再拼 HTML，否则恶意文件名会注入标签。
  const src = (path: string): string => esc(convertFileSrc(path));
  let viewer: string;
  if (info.thumbnail) {
    viewer = `<img src="${src(info.thumbnail)}" />`;
  } else if (info.type === "video" && info.entry) {
    viewer = `<video controls autoplay muted loop src="${src(info.entry)}"></video>`;
  } else if (info.type === "depth" && info.entry && ["jpg", "jpeg", "png", "webp"].includes(ext)) {
    viewer = `<img src="${src(info.entry)}" />`;
  } else if (info.type === "html" && info.entry) {
    // sandbox：第三方 HTML 与管理端保持唯一源（脚本可跑、无法碰父页面 /
    // Tauri IPC），预览他人壁纸包时不再扩大攻击面。
    viewer = `<iframe sandbox="allow-scripts" src="${src(info.entry)}"></iframe>`;
  } else {
    viewer = `<div class="empty">该类型没有可直接播放的预览，可查看下方文件列表。</div>`;
  }
  $("#preview-title").textContent = `${info.title} · ${info.type}`;
  $("#preview-view").innerHTML = `
    <div class="viewer">${viewer}</div>
    <p class="hint">包内文件：${info.files.map((file) => esc(file)).join("、")}</p>
    <pre>${esc(JSON.stringify(info.manifest, null, 2))}</pre>`;
  $("#preview-modal").classList.remove("hidden");
}

function renderSettings(): void {
  $("#tab-settings").innerHTML = `
    <div class="settings">
      <div class="field">
        <label for="cfg-api">API 地址</label>
        <input id="cfg-api" value="${esc(config.apiBase)}" placeholder="https://zuno-api.example.com" />
      </div>
      <div class="field">
        <label for="cfg-secret">Admin Secret（只存本机）</label>
        <input id="cfg-secret" type="password" value="${esc(config.adminSecret)}" />
      </div>
      <div class="field">
        <label for="cfg-dav">WebDAV 地址（管理账号，需要写权限）</label>
        <input id="cfg-dav" value="${esc(config.webdavBase)}" placeholder="https://dav.example.com/zuno" />
      </div>
      <div class="field">
        <label for="cfg-user">WebDAV 用户名</label>
        <input id="cfg-user" value="${esc(config.webdavUser)}" />
      </div>
      <div class="field">
        <label for="cfg-pass">WebDAV 密码</label>
        <input id="cfg-pass" type="password" value="${esc(config.webdavPass)}" />
      </div>
      <div class="field">
        <label for="cfg-dir">本地壁纸目录（.zuno / .zip）</label>
        <input id="cfg-dir" value="${esc(config.localDir)}" />
      </div>
      <p class="hint">Worker 上的 WebDAV 账号只读；这里填的必须是能写入 /zuno 的管理账号。
      配置文件保存在应用私有目录，不会进入仓库或云端。</p>
      <button class="btn primary" id="cfg-save">保存设置</button>
    </div>`;
  $("#cfg-save").onclick = () =>
    run(async () => {
      config = {
        apiBase: ($<HTMLInputElement>("#cfg-api").value).trim(),
        adminSecret: $<HTMLInputElement>("#cfg-secret").value,
        webdavBase: ($<HTMLInputElement>("#cfg-dav").value).trim(),
        webdavUser: $<HTMLInputElement>("#cfg-user").value,
        webdavPass: $<HTMLInputElement>("#cfg-pass").value,
        localDir: $<HTMLInputElement>("#cfg-dir").value.trim(),
      };
      await invoke("save_config", { config });
      toast("设置已保存");
      if (config.localDir) await refreshLocal();
    });
}

async function bootstrap(): Promise<void> {
  document.querySelectorAll<HTMLButtonElement>(".nav").forEach((button) => {
    button.onclick = () => switchTab(button.dataset.tab as TabName);
  });
  $("#preview-close").onclick = () => $("#preview-modal").classList.add("hidden");
  $("#preview-modal").onclick = (event) => {
    if (event.target === $("#preview-modal")) $("#preview-modal").classList.add("hidden");
  };

  await listen<Progress>("zuno-progress", (event) => {
    status(event.payload.stage, event.payload.message, event.payload.value);
  });

  config = await invoke<Config>("load_config");
  renderActions();
  renderSettings();
  await run(refreshCloud);
  if (config.localDir) await run(refreshLocal);
}

void bootstrap();
