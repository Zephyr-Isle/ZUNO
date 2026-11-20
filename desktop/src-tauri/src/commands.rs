//! Tauri 命令：前端只管交互，包的校验/压缩/上传/删除全在这里。
use std::{
    fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use serde_json::Value;
use tauri::{AppHandle, Emitter};

use crate::{
    api,
    config::AppConfig,
    models::{PackageInfo, PreviewInfo, Progress, UploadResult, WallpaperItem},
    package,
    webdav,
};

fn stamp() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or_default()
}

fn emit(app: &AppHandle, stage: &str, message: &str, value: f64) {
    let _ = app.emit(
        "zuno-progress",
        Progress {
            stage: stage.into(),
            message: message.into(),
            value,
        },
    );
}

#[tauri::command]
pub async fn load_config(app: AppHandle) -> Result<AppConfig, String> {
    AppConfig::load(&app)
}

#[tauri::command]
pub async fn save_config(app: AppHandle, config: AppConfig) -> Result<(), String> {
    config.save(&app)
}

#[tauri::command]
pub async fn health(config: AppConfig) -> Result<Value, String> {
    api::check_admin(&config).await?;
    api::health(&config).await
}

#[tauri::command]
pub async fn list_wallpapers(config: AppConfig) -> Result<Vec<WallpaperItem>, String> {
    api::list_all(&config).await
}

#[tauri::command]
pub async fn sync_catalog(app: AppHandle, config: AppConfig, limit: u32) -> Result<Value, String> {
    emit(&app, "sync", "正在扫描 WebDAV 并更新目录…", 0.0);
    let limit = limit.clamp(1, 20);
    let mut offset: u64 = 0;
    let mut passes: u32 = 0;
    let mut scanned: u64 = 0;
    let mut upserted: u64 = 0;
    let mut covers: u64 = 0;
    let mut skipped: Vec<Value> = Vec::new();

    // Worker 单次子请求有硬上限，一次只能扫一页；这里按 nextOffset 续扫。
    // 加 pass 上限兜底：万一 Worker 返回同一个 offset，不至于在这里死循环。
    loop {
        let page = api::sync_page(&config, limit, offset).await?;
        passes += 1;
        scanned += page.get("scanned").and_then(Value::as_u64).unwrap_or(0);
        upserted += page.get("upserted").and_then(Value::as_u64).unwrap_or(0);
        covers = page.get("covers").and_then(Value::as_u64).unwrap_or(covers);
        if let Some(items) = page.get("skipped").and_then(Value::as_array) {
            skipped.extend(items.iter().cloned());
        }
        emit(
            &app,
            "sync",
            &format!("已扫描 {scanned} 个包，收录 {upserted} 个"),
            (passes as f64 / (passes as f64 + 1.0)).min(0.9),
        );
        match page.get("nextOffset").and_then(Value::as_u64) {
            Some(next) if next > offset && passes < 40 => offset = next,
            _ => break,
        }
    }

    emit(&app, "sync", "同步完成", 1.0);
    Ok(serde_json::json!({
        "scanned": scanned,
        "upserted": upserted,
        "covers": covers,
        "skipped": skipped,
        "passes": passes,
        "nextOffset": Value::Null,
    }))
}

/// 删除分两段：文件由管理端直连 WebDAV 删（Worker 保持只读），
/// D1 记录再交给 `/api/admin/delete`。文件没删干净时不删 D1，
/// 否则下一次 sync 会把残留包重新收录。
#[tauri::command]
pub async fn delete_wallpaper(
    app: AppHandle,
    config: AppConfig,
    id: String,
    version: String,
) -> Result<Value, String> {
    webdav::validate(&config)?;
    let client = api::client();
    emit(&app, "delete", "正在查找 WebDAV 文件…", 0.0);

    let version_dir = format!("packages/{id}/{version}");
    let entries = webdav::list_dir(&client, &config, &version_dir).await?;
    for (name, is_dir) in entries {
        let lower = name.to_lowercase();
        if !is_dir && (lower.ends_with(".zuno") || lower.ends_with(".zip")) {
            webdav::delete_file(&client, &config, &format!("{version_dir}/{name}")).await?;
        }
    }

    if let Ok(covers) = webdav::list_dir(&client, &config, "covers").await {
        for (name, is_dir) in covers {
            let is_own_cover = name
                .rsplit_once('.')
                .map(|(stem, _)| stem == id)
                .unwrap_or(false);
            if !is_dir && is_own_cover {
                webdav::delete_file(&client, &config, &format!("covers/{name}")).await?;
            }
        }
    }

    emit(&app, "delete", "正在删除 D1 记录…", 0.7);
    let result = api::delete_remote(&config, &id).await?;
    emit(&app, "delete", "云端壁纸已删除", 1.0);
    Ok(result)
}

fn temp_package(id: &str) -> PathBuf {
    let safe: String = id
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || "._-".contains(c) { c } else { '_' })
        .collect();
    std::env::temp_dir().join(format!("zuno-remote-{safe}-{}.zuno", stamp()))
}

/// 远端预览：用 5 分钟票据把整包下载到本地，再走同一套安全解压逻辑。
#[tauri::command]
pub async fn preview_remote(
    app: AppHandle,
    config: AppConfig,
    id: String,
) -> Result<PreviewInfo, String> {
    let target = temp_package(&id);
    emit(&app, "preview", "正在从云端拉取壁纸包…", 0.0);
    api::download_to_file(&config, &id, &target).await?;
    emit(&app, "preview", "正在解析包内容…", 0.6);
    let result = package::preview(&target, "remote")?;
    emit(&app, "preview", "预览已就绪", 1.0);
    Ok(result)
}

#[tauri::command]
pub async fn preview_package(app: AppHandle, path: String) -> Result<PreviewInfo, String> {
    emit(&app, "preview", "正在解析本地包…", 0.0);
    let result = package::preview(Path::new(&path), "local")?;
    emit(&app, "preview", "预览已就绪", 1.0);
    Ok(result)
}

#[tauri::command]
pub async fn list_packages(dir: String) -> Result<Vec<PackageInfo>, String> {
    package::list_packages(Path::new(&dir))
}

/// 从源目录压缩成 .zuno：自动重算 checksum，输出路径由前端的保存对话框决定。
#[tauri::command]
pub async fn pack_directory(
    app: AppHandle,
    source: String,
    output: String,
) -> Result<PackageInfo, String> {
    emit(&app, "pack", "正在校验源目录…", 0.0);
    let info = package::pack(
        Path::new(&source),
        Path::new(&output),
        &|message| emit(&app, "pack", message, 0.4),
    )?;
    let file_name = info
        .path
        .rsplit(|c| c == '/' || c == '\\')
        .next()
        .unwrap_or("包");
    emit(&app, "pack", &format!("已生成 {file_name}"), 1.0);
    Ok(info)
}

/// 本地压缩后的包 + 封面直传 WebDAV，最后触发 Worker 同步 D1。
#[tauri::command]
pub async fn upload_package(
    app: AppHandle,
    config: AppConfig,
    package_path: String,
    cover_path: Option<String>,
    sync_limit: Option<u32>,
) -> Result<UploadResult, String> {
    webdav::validate(&config)?;
    let package_path = PathBuf::from(&package_path);
    let info = package::inspect(&package_path)?;
    let client = api::client();

    emit(&app, "upload", "正在准备 WebDAV 目录…", 0.0);
    webdav::ensure_dir(&client, &config, "packages").await?;
    // 封面目录也必须提前建好：Teracloud 等服务器对 PUT 到不存在的父目录
    // 直接回 403（不是 404），导致“上传 covers/<id>.png 失败”。后端 sync
    // 本来就要遍历 covers/，这里无条件创建对它也有好处。
    webdav::ensure_dir(&client, &config, "covers").await?;
    webdav::ensure_dir(&client, &config, &format!("packages/{}", info.id)).await?;
    let version_dir = format!("packages/{}/{}", info.id, info.version);
    webdav::ensure_dir(&client, &config, &version_dir).await?;

    let filename = package_path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or("文件名不合法")?;
    emit(&app, "upload", &format!("正在上传 {filename} …"), 0.2);
    webdav::put_file(
        &client,
        &config,
        &format!("{version_dir}/{filename}"),
        &package_path,
        "application/zip",
    )
    .await?;

    // 同时上传 manifest.json 旁车文件：Worker sync 优先读它（普通 GET），
    // 避免用 Range 从 ZIP 抠 manifest 时踩到 WebDAV 服务器的 gzip/Range 兼容坑。
    // 提取失败不阻断上传——老包仍可被 sync 的 Range 回退路径处理。
    let target_dir = package_path.parent().unwrap_or(Path::new("."));
    match package::extract_manifest(&package_path, target_dir) {
        Ok(manifest_path) => {
            if let Err(error) = webdav::put_file(
                &client,
                &config,
                &format!("{version_dir}/manifest.json"),
                &manifest_path,
                "application/json",
            )
            .await
            {
                emit(&app, "upload", &format!("manifest 旁车上传失败（不影响主包）：{error}"), 0.4);
            }
        }
        Err(error) => {
            emit(&app, "upload", &format!("提取 manifest 旁车失败（不影响主包）：{error}"), 0.4);
        }
    }

    // 封面优先用手动选的图；没选就退回包内自动生成的 thumbnail.png。
    let cover = match cover_path.as_deref() {
        Some(path) if Path::new(path).is_file() => {
            Some(package::copy_cover(Path::new(path), &info.id, target_dir)?)
        }
        _ => package::extract_cover(&package_path, &info.id, target_dir)?,
    };
    let mut uploaded_cover = None;
    if let Some(cover) = cover {
        let name = cover.file_name().and_then(|n| n.to_str()).ok_or("封面文件名不合法")?;
        let mime = if name.to_lowercase().ends_with(".png") {
            "image/png"
        } else {
            "image/jpeg"
        };
        emit(&app, "upload", "正在上传封面…", 0.5);
        webdav::put_file(&client, &config, &format!("covers/{name}"), &cover, mime).await?;
        uploaded_cover = Some(name.to_string());
    }

    emit(&app, "upload", "正在同步目录…", 0.7);
    // 单包同步：只列 packages/<id>/，上传的旁车 manifest 就在里面，几次子请求即可。
    // 整目录扫描留给「同步目录」按钮；上传时扫全量会在免费版 50 次子请求上限处中断，
    // 结果就是包已经在 WebDAV 上、D1 里却没有记录（App 目录看不到）。
    let sync = match api::sync_one(&config, &info.id).await {
        Ok(value) => value,
        Err(error) => {
            emit(&app, "upload", &format!("单包同步失败，改为整目录扫描：{error}"), 0.75);
            api::sync_page(&config, sync_limit.unwrap_or(5), 0).await?
        }
    };
    emit(&app, "upload", "上传完成", 1.0);
    Ok(UploadResult {
        package_path: package_path.to_string_lossy().into_owned(),
        cover_path: uploaded_cover,
        sync,
    })
}

#[tauri::command]
pub async fn delete_local_package(path: String, local_dir: String) -> Result<(), String> {
    package::delete_local(Path::new(&path), Path::new(&local_dir))
}

/// 把远端下载下来的临时包留到指定目录（可选），方便离线查看。
#[tauri::command]
pub async fn copy_to_local(source: String, target_dir: String) -> Result<String, String> {
    let source = Path::new(&source);
    let target = Path::new(&target_dir).join(
        source
            .file_name()
            .ok_or("源文件没有文件名")?,
    );
    fs::copy(source, &target).map_err(|e| e.to_string())?;
    Ok(target.to_string_lossy().into_owned())
}
