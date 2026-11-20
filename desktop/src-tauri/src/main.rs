// 入口：所有逻辑都在 lib.rs，便于测试与条件编译。
// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    zuno_admin_lib::run()
}
