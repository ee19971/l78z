#[flutter_rust_bridge::frb(sync)] // 同步模式，简化演示
pub fn greet(name: String) -> String {
    format!("你好, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // 默认实用程序-随意自定义
    flutter_rust_bridge::setup_default_user_utils();
}

#[flutter_rust_bridge::frb(sync)]
pub fn add(a: i64, b: i64) -> i64 {
    a + b
}
