//! `.zuno` / `.zip` 包处理：校验、算 checksum、本地压缩、安全解压预览。
//!
//! internal-docs/docs/package-format.md：两种扩展名本质都是 ZIP 容器；`checksum` 覆盖 `content/`
//! 下全部文件，按相对包根的 POSIX 路径排序后逐段喂进同一个 SHA-256。
use std::{
    collections::BTreeSet,
    fs::{self, File},
    io::{Read, Write},
    path::{Component, Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use serde_json::Value;
use sha2::{Digest, Sha256};
use zip::{write::SimpleFileOptions, CompressionMethod, ZipArchive, ZipWriter};

use crate::models::{PackageInfo, PreviewInfo};

const TYPES: [&str; 4] = ["video", "html", "depth", "timed"];

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or_default()
}

pub(crate) fn text_field(manifest: &Value, key: &str) -> Option<String> {
    manifest
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

/// 把包内相对路径安全地落到 root 下，挡住 Zip Slip。
fn safe_join(root: &Path, relative: &str) -> Result<PathBuf, String> {
    if relative.starts_with('/') || relative.contains('\\') {
        return Err(format!("非法包内路径：{relative}"));
    }
    let mut out = root.to_path_buf();
    for component in Path::new(relative).components() {
        match component {
            Component::Normal(part) => out.push(part),
            _ => return Err(format!("非法包内路径：{relative}")),
        }
    }
    // 目标文件可能还不存在：先建好父目录并规范化父目录，再拼回文件名。
    let base = fs::canonicalize(root).map_err(|e| e.to_string())?;
    let parent = out.parent().unwrap_or(root);
    fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    let parent = fs::canonicalize(parent).map_err(|e| e.to_string())?;
    let target = parent.join(out.file_name().ok_or("非法包内路径")?);
    if !target.starts_with(&base) {
        return Err(format!("路径逃逸：{relative}"));
    }
    Ok(target)
}

/// 修复 manifest 时只动 checksum；其它字段保持原样，避免管理端“顺手改坏”包。
fn validate_manifest(manifest: &Value) -> Result<(), String> {
    if manifest.get("schemaVersion").and_then(Value::as_i64) != Some(1) {
        return Err("manifest.schemaVersion 必须为 1".into());
    }
    let id = text_field(manifest, "id").ok_or("manifest 缺少 id")?;
    if id.len() > 200 || !id.chars().all(|c| c.is_ascii_alphanumeric() || "._".contains(c)) {
        return Err("id 只能包含字母、数字、点和下划线（≤200）".into());
    }
    text_field(manifest, "version").ok_or("manifest 缺少 version")?;
    text_field(manifest, "title").ok_or("manifest 缺少 title")?;
    let kind = text_field(manifest, "type").ok_or("manifest 缺少 type")?;
    if !TYPES.contains(&kind.as_str()) {
        return Err(format!("不支持的 type：{kind}"));
    }
    text_field(manifest, "entry").ok_or("manifest 缺少 entry")?;
    Ok(())
}

/// 定位包根：manifest 在 ZIP 根，或在唯一一个顶层文件夹里。
fn manifest_root(entries: &[String]) -> Option<String> {
    if entries.iter().any(|name| name == "manifest.json") {
        return Some(String::new());
    }
    let mut roots = BTreeSet::new();
    for name in entries {
        if let Some(rest) = name.strip_suffix("manifest.json") {
            let root = rest.trim_end_matches('/');
            if !root.is_empty() && !root.contains('/') {
                roots.insert(root.to_string());
            }
        }
    }
    if roots.len() == 1 {
        roots.into_iter().next()
    } else {
        None
    }
}

fn read_zip_manifest(zip: &mut ZipArchive<File>) -> Result<(String, Value), String> {
    let names: Vec<String> = (0..zip.len())
        .filter_map(|index| zip.by_index(index).ok().map(|entry| entry.name().to_string()))
        .collect();
    let root = manifest_root(&names).ok_or("ZIP 中找不到 manifest.json")?;
    let name = format!("{root}manifest.json");
    let mut entry = zip
        .by_name(&name)
        .map_err(|_| format!("ZIP 中找不到 {name}"))?;
    let mut bytes = Vec::new();
    entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    let manifest: Value = serde_json::from_slice(&bytes).map_err(|e| format!("manifest.json 非法：{e}"))?;
    Ok((root, manifest))
}

pub fn inspect(path: &Path) -> Result<PackageInfo, String> {
    let file = File::open(path).map_err(|e| format!("打开包失败：{e}"))?;
    let mut zip = ZipArchive::new(file).map_err(|e| format!("不是合法 ZIP：{e}"))?;
    let (_, manifest) = read_zip_manifest(&mut zip)?;
    validate_manifest(&manifest)?;
    let size = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
    Ok(PackageInfo {
        path: path.to_string_lossy().into_owned(),
        id: text_field(&manifest, "id").unwrap_or_default(),
        title: text_field(&manifest, "title").unwrap_or_default(),
        r#type: text_field(&manifest, "type").unwrap_or_default(),
        version: text_field(&manifest, "version").unwrap_or_default(),
        size,
        checksum: text_field(&manifest, "checksum"),
        entry: text_field(&manifest, "entry"),
    })
}

fn is_package(path: &Path) -> bool {
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("").to_lowercase();
    name.ends_with(".zuno") || name.ends_with(".zip")
}

/// 列出目录下一层的 .zuno / .zip；坏包也列出来但标注解析失败原因。
pub fn list_packages(dir: &Path) -> Result<Vec<PackageInfo>, String> {
    let entries = fs::read_dir(dir).map_err(|e| format!("读取目录失败：{e}"))?;
    let mut items = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() || !is_package(&path) {
            continue;
        }
        let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();
        match inspect(&path) {
            Ok(info) => items.push(info),
            Err(_) => items.push(PackageInfo {
                path: path.to_string_lossy().into_owned(),
                id: name.clone(),
                title: name,
                r#type: "unknown".into(),
                version: "-".into(),
                size,
                checksum: None,
                entry: None,
            }),
        }
    }
    items.sort_by(|a, b| a.title.cmp(&b.title));
    Ok(items)
}

/// 递归收集包内文件，返回 (POSIX 相对路径, 绝对路径)。
fn collect_files(root: &Path, base: &Path, out: &mut Vec<(String, PathBuf)>) -> Result<(), String> {
    for entry in fs::read_dir(root).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        // 不跟随符号链接，避免把包外文件打进包里。
        if entry.file_type().map_err(|e| e.to_string())?.is_symlink() {
            continue;
        }
        if path.is_dir() {
            collect_files(&path, base, out)?;
        } else if path.is_file() {
            let relative = path
                .strip_prefix(base)
                .map_err(|e| e.to_string())?
                .to_string_lossy()
                .replace('\\', "/");
            out.push((relative, path));
        }
    }
    Ok(())
}

fn compute_checksum(_root: &Path, files: &[(String, PathBuf)]) -> Result<String, String> {
    let mut hasher = Sha256::new();
    let mut content: Vec<&(String, PathBuf)> = files
        .iter()
        .filter(|(relative, _)| relative.starts_with("content/"))
        .collect();
    content.sort_by(|a, b| a.0.as_bytes().cmp(b.0.as_bytes()));
    for (relative, absolute) in content {
        hasher.update(relative.as_bytes());
        hasher.update([0x0A]);
        let bytes = fs::read(absolute).map_err(|e| format!("读取 {} 失败：{e}", absolute.display()))?;
        hasher.update(&bytes);
    }
    Ok(format!("sha256-{}", hex::encode(hasher.finalize())))
}

fn find_source_root(source: &Path) -> Result<PathBuf, String> {
    if source.join("manifest.json").is_file() {
        return Ok(source.to_path_buf());
    }
    let mut found = Vec::new();
    for entry in fs::read_dir(source).map_err(|e| e.to_string())? {
        let path = entry.map_err(|e| e.to_string())?.path();
        if path.is_dir() && path.join("manifest.json").is_file() {
            found.push(path);
        }
    }
    match found.len() {
        1 => Ok(found.remove(0)),
        0 => Err("目录及其直接子目录里都找不到 manifest.json".into()),
        _ => Err("找到多个 manifest.json，请把源目录指向单个壁纸".into()),
    }
}

/// 管理端本地压缩：重算 checksum 写回 manifest，再打成 .zuno（ZIP/deflate）。
pub fn pack(source: &Path, output: &Path, emit: &dyn Fn(&str)) -> Result<PackageInfo, String> {
    let root = find_source_root(source)?;
    let manifest_path = root.join("manifest.json");
    let manifest_bytes = fs::read(&manifest_path).map_err(|e| e.to_string())?;
    let mut manifest: Value = serde_json::from_slice(&manifest_bytes).map_err(|e| format!("manifest.json 非法：{e}"))?;
    validate_manifest(&manifest)?;

    let mut files = Vec::new();
    collect_files(&root, &root, &mut files)?;
    let entry = text_field(&manifest, "entry").unwrap_or_default();
    if !files.iter().any(|(relative, _)| relative == &entry) {
        return Err(format!("entry 指向的文件不存在：{entry}"));
    }
    if !files.iter().any(|(relative, _)| relative.starts_with("content/")) {
        return Err("content/ 不存在或为空".into());
    }

    emit("正在计算 checksum…");
    let checksum = compute_checksum(&root, &files)?;
    if let Some(object) = manifest.as_object_mut() {
        object.insert("checksum".into(), Value::String(checksum.clone()));
    }
    let manifest_bytes = serde_json::to_vec_pretty(&manifest).map_err(|e| e.to_string())?;

    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    emit("正在压缩 ZIP…");
    let file = File::create(output).map_err(|e| format!("创建输出文件失败：{e}"))?;
    let mut writer = ZipWriter::new(file);
    // SimpleFileOptions = FileOptions<'static, ()>：() 与 ExtendedFileOptions
    // 都实现了同一组 builder 方法，裸 FileOptions::default() 推断不出 T。
    let options = SimpleFileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .unix_permissions(0o644);

    writer.start_file("manifest.json", options).map_err(|e| e.to_string())?;
    writer.write_all(&manifest_bytes).map_err(|e| e.to_string())?;

    // 源目录有 thumbnail.png 就直接沿用；没有则按 type 自动生成（视频取首帧、
    // 图片缩放、HTML 离屏渲染）。根级 thumbnail.png 不参与 content/ 的 checksum，
    // 所以这里临时生成不会影响上面写回 manifest 的 checksum。
    let thumbnail_bytes = {
        let existing = root.join("thumbnail.png");
        if existing.is_file() {
            Some(fs::read(&existing).map_err(|e| e.to_string())?)
        } else {
            let generated = crate::thumbnail::generate(&root, &manifest, emit).and_then(|path| {
                let bytes = fs::read(&path).ok();
                let _ = fs::remove_file(&path);
                bytes
            });
            if generated.is_none() {
                emit("未能自动生成预览图，客户端导入时会补图");
            }
            generated
        }
    };
    if let Some(bytes) = thumbnail_bytes {
        writer.start_file("thumbnail.png", options).map_err(|e| e.to_string())?;
        writer.write_all(&bytes).map_err(|e| e.to_string())?;
    }

    for (relative, absolute) in &files {
        if relative == "manifest.json" || relative == "thumbnail.png" {
            continue;
        }
        writer.start_file(relative, options).map_err(|e| e.to_string())?;
        let mut input = File::open(absolute).map_err(|e| e.to_string())?;
        std::io::copy(&mut input, &mut writer).map_err(|e| e.to_string())?;
    }
    writer.finish().map_err(|e| e.to_string())?;

    let mut info = inspect(output)?;
    info.checksum = Some(checksum);
    Ok(info)
}

/// 安全解到独立临时目录，并返回前端可直接 convertFileSrc 的路径。
pub fn preview(path: &Path, tag: &str) -> Result<PreviewInfo, String> {
    let info = inspect(path)?;
    let unique = format!("zuno-preview-{}-{}", tag, now_millis());
    let dir = std::env::temp_dir().join(unique);
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;

    let mut zip = ZipArchive::new(File::open(path).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    let mut files = Vec::new();
    for index in 0..zip.len() {
        let mut entry = zip.by_index(index).map_err(|e| e.to_string())?;
        let name = entry.name().replace('\\', "/");
        if entry.is_dir() {
            continue;
        }
        let target = safe_join(&dir, &name)?;
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
        let mut output = File::create(&target).map_err(|e| e.to_string())?;
        std::io::copy(&mut entry, &mut output).map_err(|e| e.to_string())?;
        files.push(name);
    }

    let root = manifest_root(&files).ok_or("解压后找不到 manifest.json")?;
    let root_path = if root.is_empty() {
        dir.clone()
    } else {
        dir.join(root.trim_end_matches('/'))
    };
    let manifest_bytes = fs::read(root_path.join("manifest.json")).map_err(|e| e.to_string())?;
    let manifest: Value = serde_json::from_slice(&manifest_bytes).map_err(|e| e.to_string())?;

    let thumbnail = root_path.join("thumbnail.png");
    let exists = |path: &Path| path.is_file().then(|| path.to_string_lossy().into_owned());
    // manifest 来自远端包，entry 可控：写 "/etc/passwd" 或 "../.." 时
    // Path::join 会逃逸出包目录，前端 convertFileSrc 就能读到任意系统文件。
    // 必须复用 safe_join 收口（非法/逃逸路径 → entry 为空，只影响预览）。
    let entry = text_field(&manifest, "entry")
        .and_then(|name| safe_join(&root_path, &name).ok())
        .and_then(|target| exists(&target));

    Ok(PreviewInfo {
        path: path.to_string_lossy().into_owned(),
        r#type: info.r#type,
        title: info.title,
        manifest,
        extracted_dir: root_path.to_string_lossy().into_owned(),
        thumbnail: exists(&thumbnail),
        entry,
        files,
    })
}

/// 只删除本地目录内的包，避免误删任意路径。
pub fn delete_local(path: &Path, local_dir: &Path) -> Result<(), String> {
    if !is_package(path) {
        return Err("只允许删除 .zuno / .zip 文件".into());
    }
    let base = fs::canonicalize(local_dir).map_err(|e| format!("本地目录无效：{e}"))?;
    let target = fs::canonicalize(path).map_err(|e| format!("文件不存在：{e}"))?;
    if !target.starts_with(&base) {
        return Err("文件不在当前本地目录内".into());
    }
    fs::remove_file(&target).map_err(|e| format!("删除失败：{e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pack_refreshes_checksum_and_inspects() {
        let unique = now_millis();
        let root = std::env::temp_dir().join(format!("zuno-pack-test-{unique}"));
        let output = std::env::temp_dir().join(format!("zuno-pack-test-{unique}.zuno"));
        fs::create_dir_all(root.join("content")).unwrap();
        fs::write(
            root.join("manifest.json"),
            r#"{"schemaVersion":1,"id":"com.test.demo","version":"1.0.0","title":"Demo","type":"html","entry":"content/index.html","checksum":"wrong"}"#,
        )
        .unwrap();
        fs::write(root.join("content/index.html"), "<h1>hi</h1>").unwrap();

        let info = pack(&root, &output, &|_| {}).unwrap();
        assert_eq!(info.id, "com.test.demo");
        assert_eq!(info.title, "Demo");
        assert!(info.checksum.as_deref().unwrap().starts_with("sha256-"));
        assert_ne!(info.checksum.as_deref().unwrap(), "wrong");

        let inspected = inspect(&output).unwrap();
        assert_eq!(inspected.r#type, "html");
        assert_eq!(inspected.entry.as_deref(), Some("content/index.html"));

        let preview = preview(&output, "test").unwrap();
        assert_eq!(preview.title, "Demo");
        assert!(preview.entry.is_some());

        fs::remove_dir_all(&root).unwrap();
        fs::remove_file(&output).unwrap();
    }

    #[test]
    fn pack_auto_thumbnail_and_cover_extraction() {
        let unique = now_millis();
        let root = std::env::temp_dir().join(format!("zuno-thumb-test-{unique}"));
        let output = std::env::temp_dir().join(format!("zuno-thumb-test-{unique}.zuno"));
        let cover_dir = std::env::temp_dir().join(format!("zuno-cover-test-{unique}"));
        fs::create_dir_all(root.join("content")).unwrap();
        fs::create_dir_all(&cover_dir).unwrap();
        fs::write(
            root.join("manifest.json"),
            r#"{"schemaVersion":1,"id":"com.test.thumb","version":"1.0.0","title":"Thumb","type":"html","entry":"content/index.html"}"#,
        )
        .unwrap();
        fs::write(root.join("content/index.html"), "<h1>preview</h1>").unwrap();

        let info = pack(&root, &output, &|_| {}).unwrap();
        let mut zip = ZipArchive::new(File::open(&output).unwrap()).unwrap();
        let names: Vec<String> = (0..zip.len())
            .map(|index| zip.by_index(index).unwrap().name().to_string())
            .collect();

        if names.iter().any(|name| name == "thumbnail.png") {
            let cover = extract_cover(&output, &info.id, &cover_dir)
                .unwrap()
                .expect("包内有预览图时应能提取为封面");
            assert_eq!(
                cover.file_name().unwrap().to_string_lossy(),
                format!("{}.png", info.id)
            );
            let bytes = fs::read(&cover).unwrap();
            assert!(bytes.starts_with(&[0x89, b'P', b'N', b'G']), "提取的封面应是 PNG");
        } else {
            eprintln!("当前环境没有可用的浏览器，跳过自动预览图断言");
        }

        // 设 ZUNO_KEEP_E2E=1 可保留产物，便于人工检查生成的预览图。
        if std::env::var_os("ZUNO_KEEP_E2E").is_some() {
            eprintln!(
                "E2E root={} output={} cover_dir={}",
                root.display(),
                output.display(),
                cover_dir.display()
            );
        } else {
            fs::remove_dir_all(&root).unwrap();
            fs::remove_file(&output).unwrap();
            fs::remove_dir_all(&cover_dir).unwrap();
        }
    }
}

/// 把用户选的封面复制到包旁边，供上传时使用（统一命名 <id>.jpg/.png）。
pub fn copy_cover(source: &Path, id: &str, target_dir: &Path) -> Result<PathBuf, String> {
    let extension = source
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("jpg")
        .to_lowercase();
    let extension = if extension == "jpeg" {
        "jpg".to_string()
    } else {
        extension
    };
    let safe_id: String = id.chars().map(|c| if c.is_ascii_alphanumeric() || "._-".contains(c) { c } else { '_' }).collect();
    let target = target_dir.join(format!("{safe_id}.{extension}"));
    fs::copy(source, &target).map_err(|e| format!("复制封面失败：{e}"))?;
    Ok(target)
}

/// 没手动选封面时，从包内提取自动生成的 `thumbnail.png` 当云端封面。
/// 写到包目录旁的 `<id>.png`，命名与 `copy_cover` 一致，删除时可按 id 一起清理。
pub fn extract_cover(
    package: &Path,
    id: &str,
    target_dir: &Path,
) -> Result<Option<PathBuf>, String> {
    let file = File::open(package).map_err(|e| e.to_string())?;
    let mut zip = ZipArchive::new(file).map_err(|e| e.to_string())?;
    let (root, _) = read_zip_manifest(&mut zip)?;
    let name = format!("{root}thumbnail.png");
    let mut entry = match zip.by_name(&name) {
        Ok(entry) => entry,
        Err(_) => return Ok(None),
    };
    let mut bytes = Vec::new();
    entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    let safe_id: String = id
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || "._-".contains(c) { c } else { '_' })
        .collect();
    let target = target_dir.join(format!("{safe_id}.png"));
    fs::write(&target, &bytes).map_err(|e| format!("写入封面失败：{e}"))?;
    Ok(Some(target))
}

/// 把包内 manifest.json 的原始字节提取到包旁边（manifest.json sidecar）。
///
/// Worker sync 原本要用三次 Range 请求从 ZIP 中央目录抠 manifest，但部分
/// WebDAV 服务器对带 gzip 的 Range 会忽略字节范围、返回整文件，导致收录失败。
/// 上传时额外放一份小 manifest 旁车文件，Worker 直接普通 GET 读它即可，
/// 彻底绕开 Range。返回写好的路径。
pub fn extract_manifest(package: &Path, target_dir: &Path) -> Result<PathBuf, String> {
    let file = File::open(package).map_err(|e| e.to_string())?;
    let mut zip = ZipArchive::new(file).map_err(|e| e.to_string())?;
    let (root, _) = read_zip_manifest(&mut zip)?;
    let name = format!("{root}manifest.json");
    let mut entry = zip
        .by_name(&name)
        .map_err(|_| format!("ZIP 中找不到 {name}"))?;
    let mut bytes = Vec::new();
    entry.read_to_end(&mut bytes).map_err(|e| e.to_string())?;
    let target = target_dir.join("manifest.json");
    fs::write(&target, &bytes).map_err(|e| format!("写入 manifest 旁车失败：{e}"))?;
    Ok(target)
}
