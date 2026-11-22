//! WebDAV 写入：只给管理端用。Worker 对 WebDAV 只读，上传绝不经过 Worker。
//!
//! 上传布局严格按 internal-docs/docs/backend.md：`packages/<id>/<version>/<file>.zuno`
//! 与 `covers/<id>.<ext>`。
use std::{fs, path::Path};

use base64::{engine::general_purpose::STANDARD, Engine};
use reqwest::{Client, StatusCode};

use crate::config::AppConfig;

pub fn validate(config: &AppConfig) -> Result<(), String> {
    if config.webdav_base().is_empty() {
        return Err("请先在设置里填写 WebDAV 地址".into());
    }
    if config.webdav_user.is_empty() || config.webdav_pass.is_empty() {
        return Err("请先在设置里填写 WebDAV 账号和密码（需要写权限）".into());
    }
    Ok(())
}

fn authorization(config: &AppConfig) -> String {
    format!(
        "Basic {}",
        STANDARD.encode(format!("{}:{}", config.webdav_user, config.webdav_pass))
    )
}

/// 逐段编码，保留 `/`；空段跳过，`.`/`..` 直接拒绝（与 backend 的 encodePath
/// 同语义）。此前把 `..` 静默改写成空段——含遍历段的路径会被改写后照常发出，
/// 删除/上传可能命中意料之外的目录，必须显式报错。
pub fn encode_path(path: &str) -> Result<String, String> {
    let mut out = Vec::new();
    for segment in path.split('/') {
        if segment.is_empty() {
            continue;
        }
        if segment == "." || segment == ".." {
            return Err(format!("非法 WebDAV 路径段 \"{segment}\"（{path}）"));
        }
        out.push(urlencoding::encode(segment).into_owned());
    }
    Ok(out.join("/"))
}

fn url(config: &AppConfig, relative: &str) -> Result<String, String> {
    Ok(format!("{}/{}", config.webdav_base(), encode_path(relative)?))
}

/// MKCOL 已存在会返回 405，视为成功（可重复上传同一 id/version）。
pub async fn ensure_dir(client: &Client, config: &AppConfig, relative: &str) -> Result<(), String> {
    let endpoint = url(config, relative)?;
    let response = client
        .request(reqwest::Method::from_bytes(b"MKCOL").unwrap(), endpoint)
        .header("authorization", authorization(config))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    match response.status() {
        StatusCode::CREATED | StatusCode::NO_CONTENT | StatusCode::METHOD_NOT_ALLOWED => Ok(()),
        other => Err(format!("创建 WebDAV 目录 {relative} 失败（HTTP {other}）")),
    }
}

/// WebDAV PROPFIND（depth=1）：返回 (文件名, 是否目录)。
/// 桌面端用它在删除前找出版本目录下的 `.zuno` / `.zip` 与对应封面。
pub async fn list_dir(
    client: &Client,
    config: &AppConfig,
    relative: &str,
) -> Result<Vec<(String, bool)>, String> {
    const BODY: &str = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\
<d:propfind xmlns:d=\"DAV:\"><d:prop><d:resourcetype/></d:prop></d:propfind>";
    let response = client
        .request(
            reqwest::Method::from_bytes(b"PROPFIND").unwrap(),
            url(config, relative)?,
        )
        .header("authorization", authorization(config))
        .header("depth", "1")
        .header("content-type", "application/xml; charset=utf-8")
        .body(BODY)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if response.status() != reqwest::StatusCode::MULTI_STATUS {
        return Err(format!("PROPFIND {relative} 失败（HTTP {}）", response.status()));
    }
    let xml = response.text().await.map_err(|e| e.to_string())?;

    let response_re = regex::Regex::new(
        r"<(?:[A-Za-z0-9_-]+:)?response\b[^>]*>([\s\S]*?)</(?:[A-Za-z0-9_-]+:)?response>",
    )
    .unwrap();
    let href_re = regex::Regex::new(
        r"<(?:[A-Za-z0-9_-]+:)?href\b[^>]*>([\s\S]*?)</(?:[A-Za-z0-9_-]+:)?href>",
    )
    .unwrap();
    let collection_re = regex::Regex::new(r"<(?:[A-Za-z0-9_-]+:)?collection\b").unwrap();

    let mut out = Vec::new();
    for block in response_re.captures_iter(&xml) {
        let Some(href) = href_re.captures(&block[1]).and_then(|c| c.get(1)) else {
            continue;
        };
        let raw = href.as_str().trim();
        let path = raw
            .split('?')
            .next()
            .unwrap_or(raw)
            .trim_end_matches('/');
        let name = path.rsplit('/').next().unwrap_or("");
        if name.is_empty() {
            continue; // 目录自身
        }
        let decoded = urlencoding::decode(name);
        let name = match decoded {
            // 解码失败/空名：条目不可信，直接跳过。此前 unwrap_or_default 会
            // 产出空名继续参与匹配，delete 漏删真实文件却照样清 D1 行，
            // 下次 sync 又把半删除状态重新收录。
            Ok(value) if !value.is_empty() => value.into_owned(),
            _ => continue,
        };
        out.push((name, collection_re.is_match(&block[1])));
    }
    Ok(out)
}

/// WebDAV DELETE：404 视为已删除。Worker 不用这个方法——只有管理端直连。
pub async fn delete_file(
    client: &Client,
    config: &AppConfig,
    relative: &str,
) -> Result<(), String> {
    let response = client
        .delete(url(config, relative)?)
        .header("authorization", authorization(config))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    match response.status() {
        StatusCode::OK | StatusCode::NO_CONTENT | StatusCode::NOT_FOUND => Ok(()),
        other => Err(format!("删除 {relative} 失败（HTTP {other}）")),
    }
}

/// 桌面端内存充足，整文件读入即可；Worker 侧才必须流式。
pub async fn put_file(
    client: &Client,
    config: &AppConfig,
    relative: &str,
    file: &Path,
    content_type: &str,
) -> Result<(), String> {
    let bytes = fs::read(file).map_err(|e| format!("读取待上传文件失败：{e}"))?;
    let response = client
        .put(url(config, relative)?)
        .header("authorization", authorization(config))
        .header("content-type", content_type)
        .body(bytes)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    match response.status() {
        StatusCode::CREATED | StatusCode::NO_CONTENT | StatusCode::OK => Ok(()),
        other => Err(format!("上传 {relative} 失败（HTTP {other}）")),
    }
}
