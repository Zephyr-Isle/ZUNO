//! Worker API 客户端：目录、票据、下载、管理端同步与删除。
use std::{
    fs::File,
    io::Write,
    path::Path,
    sync::OnceLock,
    time::Duration,
};

use futures_util::StreamExt;
use reqwest::{Client, StatusCode};
use serde_json::Value;

use crate::{config::AppConfig, models::WallpaperItem};

/// 全局复用一个 Client：reqwest 的 Client 内部带 TCP/TLS 连接池，
/// 每次请求都重新 builder().build() 会丢掉连接池——实测同一条连接复用后
/// 首字节从 ~1s 降到 ~0.3s，还能避开新建连接时的随机 RST。
static CLIENT: OnceLock<Client> = OnceLock::new();

pub fn client() -> &'static Client {
    CLIENT.get_or_init(|| {
        Client::builder()
            .user_agent("zuno-admin/0.1")
            // 部分网络链路到 Cloudflare 的 HTTP/2 连接会被随机 RST
            // （os error 10054），强制 HTTP/1.1 实测稳定得多；API 都是普通
            // JSON，用 h1 没有功能损失。连接/整体超时避免网络抖动时无限等待。
            .http1_only()
            .connect_timeout(Duration::from_secs(20))
            .timeout(Duration::from_secs(90))
            .build()
            .unwrap_or_else(|_| Client::new())
    })
}

/// 把 reqwest 错误连同底层 cause 一起展开，便于区分“连接被重置”和 HTTP 错误。
/// 之前只用 e.to_string() 丢掉了 cause，报错只剩一句 “error sending request”。
fn error_chain(error: &reqwest::Error) -> String {
    let mut message = error.to_string();
    let mut source = std::error::Error::source(error);
    while let Some(cause) = source {
        message.push_str(" <- ");
        message.push_str(&cause.to_string());
        source = cause.source();
    }
    message
}

/// 连接被重置/超时是瞬时故障，重试几次；每次重建请求（RequestBuilder 不可复用）。
async fn send_with_retry(
    build: impl Fn() -> reqwest::RequestBuilder,
    action: &str,
) -> Result<reqwest::Response, String> {
    const ATTEMPTS: u32 = 3;
    let mut last = String::new();
    for attempt in 0..ATTEMPTS {
        match build().send().await {
            Ok(response) => return Ok(response),
            Err(error) => {
                last = error_chain(&error);
                if attempt + 1 < ATTEMPTS {
                    tokio::time::sleep(Duration::from_millis(600 * (attempt + 1) as u64)).await;
                }
            }
        }
    }
    Err(format!("{action} 失败（重试 {ATTEMPTS} 次）：{last}"))
}

async fn ensure(response: reqwest::Response, action: &str) -> Result<reqwest::Response, String> {
    let status = response.status();
    if status.is_success() {
        return Ok(response);
    }
    let body = response.text().await.unwrap_or_default();
    Err(format!("{action} 失败（HTTP {status}）：{}", truncate(&body, 300)))
}

fn truncate(text: &str, max: usize) -> &str {
    if text.chars().count() <= max {
        return text;
    }
    text.char_indices()
        .nth(max)
        .map(|(index, _)| &text[..index])
        .unwrap_or(text)
}

/// 游标分页拿全量目录；上限只是防止配置错误时无限循环。
pub async fn list_all(config: &AppConfig) -> Result<Vec<WallpaperItem>, String> {
    let base = config.api_base();
    let mut cursor: Option<String> = None;
    let mut all = Vec::new();
    loop {
        let mut url = format!("{base}/api/wallpapers?limit=50");
        if let Some(value) = cursor.as_deref() {
            url.push_str(&format!("&cursor={}", urlencoding::encode(value)));
        }
        let response = ensure(send_with_retry(|| client().get(&url), "读取目录").await?, "读取目录").await?;
        let body: Value = response.json().await.map_err(|e| format!("解析目录失败：{e}"))?;
        let items = body.get("items").and_then(Value::as_array).ok_or("目录响应缺少 items")?;
        for item in items {
            if let Ok(row) = serde_json::from_value::<WallpaperItem>(item.clone()) {
                all.push(row);
            }
        }
        cursor = body
            .get("nextCursor")
            .and_then(Value::as_str)
            .filter(|value| !value.is_empty())
            .map(str::to_string);
        if cursor.is_none() || items.is_empty() || all.len() > 5000 {
            break;
        }
    }
    Ok(all)
}

pub async fn health(config: &AppConfig) -> Result<Value, String> {
    let url = format!("{}/health", config.api_base());
    let response = ensure(send_with_retry(|| client().get(&url), "健康检查").await?, "健康检查").await?;
    response.json().await.map_err(|e| e.to_string())
}

/// 换取 5 分钟一次性票据并流式下载整包到临时文件。
pub async fn download_to_file(config: &AppConfig, id: &str, dest: &Path) -> Result<(), String> {
    let base = config.api_base();
    let ticket_url = format!(
        "{}/api/wallpapers/{}/ticket",
        base,
        urlencoding::encode(id)
    );
    let response = ensure(send_with_retry(|| client().post(&ticket_url), "换取票据").await?, "换取票据").await?;
    let body: Value = response.json().await.map_err(|e| format!("解析票据失败：{e}"))?;
    let url = body
        .get("url")
        .and_then(Value::as_str)
        .ok_or("票据响应缺少 url")?;
    let url = if url.starts_with("http://") || url.starts_with("https://") {
        url.to_string()
    } else {
        format!("{base}{url}")
    };

    let response = ensure(send_with_retry(|| client().get(&url), "下载壁纸包").await?, "下载壁纸包").await?;
    let mut file = File::create(dest).map_err(|e| format!("创建临时文件失败：{e}"))?;
    let mut stream = response.bytes_stream();
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| format!("下载中断：{e}"))?;
        file.write_all(&chunk).map_err(|e| format!("写入临时文件失败：{e}"))?;
    }
    file.flush().map_err(|e| e.to_string())?;
    Ok(())
}

/// 批量同步一页。Worker 按 WebDAV 修改时间倒序取 `limit` 个包目录，
/// 响应里的 `nextOffset` 为 null 表示扫完；调用方循环直到它为 null。
pub async fn sync_page(config: &AppConfig, limit: u32, offset: u64) -> Result<Value, String> {
    let url = format!(
        "{}/api/admin/sync?limit={}&offset={}",
        config.api_base(),
        limit.clamp(1, 20),
        offset
    );
    let response = ensure(
        send_with_retry(
            || client().post(&url).header("x-admin-secret", &config.admin_secret),
            "同步目录",
        )
        .await?,
        "同步目录",
    )
    .await?;
    response.json().await.map_err(|e| e.to_string())
}

/// 只同步一个包：上传后立刻调用。
///
/// 整目录扫描会为每个包再发 2–3 次 PROPFIND，免费版 Worker 单次 50 次子请求
/// 很容易被老包（无 manifest 旁车、要走三次 Range）吃光；单包模式只列
/// `packages/<id>/`，通常 4 次子请求内完成。
pub async fn sync_one(config: &AppConfig, id: &str) -> Result<Value, String> {
    let url = format!(
        "{}/api/admin/sync?id={}",
        config.api_base(),
        urlencoding::encode(id)
    );
    let response = ensure(
        send_with_retry(
            || client().post(&url).header("x-admin-secret", &config.admin_secret),
            "同步壁纸",
        )
        .await?,
        "同步壁纸",
    )
    .await?;
    response.json().await.map_err(|e| e.to_string())
}

pub async fn delete_remote(config: &AppConfig, id: &str) -> Result<Value, String> {
    let url = format!("{}/api/admin/delete", config.api_base());
    let response = ensure(
        send_with_retry(
            || {
                client()
                    .post(&url)
                    .header("x-admin-secret", &config.admin_secret)
                    .json(&serde_json::json!({ "id": id }))
            },
            "删除云端壁纸",
        )
        .await?,
        "删除云端壁纸",
    )
    .await?;
    response.json().await.map_err(|e| e.to_string())
}

/// 只探测配置是否可用，不修改任何数据。
pub async fn check_admin(config: &AppConfig) -> Result<bool, String> {
    let url = format!("{}/api/wallpapers?limit=1", config.api_base());
    let response = send_with_retry(|| client().get(&url), "检查 API").await?;
    if response.status() == StatusCode::OK {
        Ok(true)
    } else {
        Err(format!("API 返回 HTTP {}", response.status()))
    }
}
