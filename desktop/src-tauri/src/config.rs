//! 管理端配置：API 地址、Admin Secret、WebDAV 读写账号。
//!
//! 只落在应用自己的配置目录（`app_config_dir/config.json`），不进仓库、不进
//! Worker。Admin Secret 与 WebDAV 密码是本机明文保存——这是管理端工具，
//! 机器本身必须可信；不要把配置文件同步到公共网盘。
use std::{fs, path::PathBuf};

use serde::{Deserialize, Serialize};
use tauri::{AppHandle, Manager};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppConfig {
    pub api_base: String,
    pub admin_secret: String,
    pub webdav_base: String,
    pub webdav_user: String,
    pub webdav_pass: String,
    /// 本地壁纸目录，用于列出/预览/删除 .zuno 与 .zip。
    pub local_dir: String,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            api_base: "https://zuno-api.zephyrisle.qzz.io".into(),
            admin_secret: String::new(),
            webdav_base: String::new(),
            webdav_user: String::new(),
            webdav_pass: String::new(),
            local_dir: String::new(),
        }
    }
}

impl AppConfig {
    fn path(app: &AppHandle) -> Result<PathBuf, String> {
        let dir = app
            .path()
            .app_config_dir()
            .map_err(|e| format!("无法定位配置目录：{e}"))?;
        fs::create_dir_all(&dir).map_err(|e| format!("无法创建配置目录：{e}"))?;
        Ok(dir.join("config.json"))
    }

    pub fn load(app: &AppHandle) -> Result<Self, String> {
        let path = Self::path(app)?;
        if !path.exists() {
            return Ok(Self::default());
        }
        let text = fs::read_to_string(&path).map_err(|e| format!("读取配置失败：{e}"))?;
        serde_json::from_str(&text).map_err(|e| format!("配置格式错误：{e}"))
    }

    pub fn save(&self, app: &AppHandle) -> Result<(), String> {
        let path = Self::path(app)?;
        let text = serde_json::to_string_pretty(self).map_err(|e| e.to_string())?;
        fs::write(&path, text).map_err(|e| format!("保存配置失败：{e}"))
    }

    /// API base 去掉末尾斜杠，拼接时不会出现 `//api/...`。
    pub fn api_base(&self) -> String {
        self.api_base.trim().trim_end_matches('/').to_string()
    }

    pub fn webdav_base(&self) -> String {
        self.webdav_base.trim().trim_end_matches('/').to_string()
    }
}
