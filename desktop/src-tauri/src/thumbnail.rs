//! 自动生成壁纸包预览图（塞进 `.zuno` 的 `thumbnail.png`）。
//!
//! - `video` / `depth`：调 ffmpeg 取首帧或缩放颜色图，统一按 480×800 留边输出。
//! - `html`：调系统 Edge / Chrome 无头模式真实渲染 entry 页面后截图。
//! - `timed`：父包自身不渲染，跳过（客户端显示占位图标）。
//!
//! 任何一步失败都只返回 `None`，绝不阻断打包；包内没有预览图时客户端
//! 导入器会自动补一张（见 README §5 第 9 条）。
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

use serde_json::Value;

use crate::package::text_field;

fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or_default()
}

/// 从 PATH 找可执行文件；`split_paths` 处理 Windows 的 `;` 分隔符，文件名带 `.exe`。
fn find_executable(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|dir| dir.join(name))
        .find(|candidate| candidate.is_file())
}

/// 优先系统 Edge（Win11 自带），其次 Chrome。
fn find_browser() -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Some(local) = std::env::var_os("LOCALAPPDATA") {
        candidates.push(PathBuf::from(local).join(r"Microsoft\Edge\Application\msedge.exe"));
    }
    candidates.extend([
        PathBuf::from(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        PathBuf::from(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
        PathBuf::from(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        PathBuf::from(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    ]);
    candidates
        .into_iter()
        .find(|path| path.is_file())
        .or_else(|| find_executable("msedge.exe"))
        .or_else(|| find_executable("chrome.exe"))
}

/// 静默执行外部工具；输出全部丢弃，避免污染管理端进度条。
fn run(exe: &Path, args: &[&str]) -> bool {
    Command::new(exe)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

/// 等比缩放后居中留边，四种类型的预览图尺寸一致。
const SCALE_FILTER: &str =
    "scale=480:800:force_original_aspect_ratio=decrease,pad=480:800:(ow-iw)/2:(oh-ih)/2";

/// video / depth 都走 ffmpeg：视频取首帧，图片取第一帧（防 webp 动画多帧）。
fn ffmpeg_thumb(input: &Path, output: &Path) -> bool {
    let Some(ffmpeg) = find_executable("ffmpeg.exe") else {
        return false;
    };
    let input = input.to_string_lossy().into_owned();
    let output = output.to_string_lossy().into_owned();
    run(
        &ffmpeg,
        &[
            "-y",
            "-loglevel",
            "error",
            "-i",
            &input,
            "-frames:v",
            "1",
            "-vf",
            SCALE_FILTER,
            &output,
        ],
    )
}

/// 把本地路径转成 `file:///` URL 供浏览器加载（相对资源按 entry 所在目录解析）。
fn file_url(path: &Path) -> String {
    let absolute = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    let raw = absolute.to_string_lossy();
    // Windows 的 canonicalize 返回 `\\?\C:\...`，浏览器不认这个前缀，
    // 不去掉会打开失败并落到 Edge 默认页（截出来是隐私同意页）。
    let trimmed = raw.strip_prefix(r"\\?\").unwrap_or(raw.as_ref());
    format!("file:///{}", trimmed.replace('\\', "/"))
}

/// html 用无头浏览器真实渲染后截图；独立 user-data-dir 避免与已开浏览器冲突。
fn browser_shot(input: &Path, output: &Path) -> bool {
    let Some(browser) = find_browser() else {
        return false;
    };
    let url = file_url(input);
    let profile = std::env::temp_dir().join(format!("zuno-thumb-profile-{}", now_millis()));
    let user_data = format!("--user-data-dir={}", profile.display());
    let screenshot = format!("--screenshot={}", output.display());
    let ok = run(
        &browser,
        &[
            "--headless=new",
            // 全新临时 profile 会触发 Edge 的首次运行隐私同意页，必须显式关掉，
            // 否则截到的是同意页而不是壁纸内容。
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-search-engine-choice-screen",
            "--disable-gpu",
            "--no-sandbox",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--window-size=480,800",
            "--virtual-time-budget=2000",
            &user_data,
            &screenshot,
            &url,
        ],
    );
    let _ = fs::remove_dir_all(&profile);
    ok
}

/// 按 manifest 的 type/entry 生成预览图，成功时返回临时 PNG 路径（调用方负责删除）。
pub fn generate(root: &Path, manifest: &Value, emit: &dyn Fn(&str)) -> Option<PathBuf> {
    let kind = text_field(manifest, "type")?;
    let entry = text_field(manifest, "entry")?;
    // entry 来自待打包的 manifest，仍按 safe_join 的规则拒绝绝对路径与 `..`。
    if entry.starts_with('/') || entry.contains('\\') || entry.contains("..") {
        return None;
    }
    let input = root.join(&entry);
    if !input.is_file() {
        return None;
    }
    let output = std::env::temp_dir().join(format!("zuno-thumb-{}-{}.png", kind, now_millis()));
    let ok = match kind.as_str() {
        "video" | "depth" => {
            emit(&format!("正在为 {kind} 生成预览图…"));
            ffmpeg_thumb(&input, &output)
        }
        "html" => {
            emit("正在渲染 HTML 生成预览图…");
            browser_shot(&input, &output)
        }
        // timed 父包自身不渲染。
        _ => false,
    };
    if ok
        && fs::metadata(&output)
            .map(|meta| meta.len() > 0)
            .unwrap_or(false)
    {
        Some(output)
    } else {
        let _ = fs::remove_file(&output);
        None
    }
}
