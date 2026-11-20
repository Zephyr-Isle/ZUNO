//! ZUNO 壁纸管理端：远程目录管理 + 本地包压缩/预览/上传/删除。
mod api;
mod commands;
mod config;
mod models;
mod package;
mod thumbnail;
mod webdav;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            commands::load_config,
            commands::save_config,
            commands::health,
            commands::list_wallpapers,
            commands::sync_catalog,
            commands::delete_wallpaper,
            commands::preview_remote,
            commands::preview_package,
            commands::list_packages,
            commands::pack_directory,
            commands::upload_package,
            commands::delete_local_package,
            commands::copy_to_local,
        ])
        .run(tauri::generate_context!())
        .expect("ZUNO 管理端启动失败");
}
