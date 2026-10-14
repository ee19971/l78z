//! 互传助手 · Windows 桌面「倒数日列表」部件的独立入口。
//!
//! 与主程序（l78z.exe，Flutter）同包分发，但互不相干：
//! 部件只读 `Documents\countdown-events.json`，不碰 Flutter 引擎。
//! 构建方式见 Cargo.toml 中 widget feature 的注释。
//!
//! 发布版不带控制台窗口（静默运行），调试版保留控制台方便看日志。
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(windows)]
fn main() {
    rust_lib_l78z::widget::run();
}

#[cfg(not(windows))]
fn main() {
    eprintln!("l78z_widget 仅支持 Windows");
    std::process::exit(1);
}
