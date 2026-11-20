//! 管理端与前端之间的数据契约（统一 camelCase，和 Worker API 对齐）。
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WallpaperItem {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub author: Option<String>,
    pub r#type: String,
    pub version: String,
    pub size: u64,
    pub updated_at: u64,
}

/// 本地/远端 ZIP 包的基本信息；预览前只解析 manifest，不解压素材。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PackageInfo {
    pub path: String,
    pub id: String,
    pub title: String,
    pub r#type: String,
    pub version: String,
    pub size: u64,
    #[serde(default)]
    pub checksum: Option<String>,
    #[serde(default)]
    pub entry: Option<String>,
}

/// 预览：ZIP 已安全解到临时目录，前端用 convertFileSrc() 播放/显示。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PreviewInfo {
    pub path: String,
    pub r#type: String,
    pub title: String,
    pub manifest: Value,
    pub extracted_dir: String,
    pub thumbnail: Option<String>,
    pub entry: Option<String>,
    pub files: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Progress {
    pub stage: String,
    pub message: String,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UploadResult {
    pub package_path: String,
    pub cover_path: Option<String>,
    pub sync: Value,
}
