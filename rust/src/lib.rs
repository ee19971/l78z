pub mod api;
mod frb_generated;
pub mod util;

// Windows 桌面部件（独立进程 l78z_widget.exe）。只在 Windows 目标下编译，
// 见 Cargo.toml 的 widget feature 与 src/bin/l78z_widget.rs。
#[cfg(windows)]
pub mod widget;
