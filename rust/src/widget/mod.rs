//! Windows 桌面「倒数日列表」部件（独立进程 l78z_widget.exe）。
//!
//! 架构：
//! - **窗口**：tao 无边框透明窗口，SetParent 进 Explorer 的桌面层
//!   （WorkerW 或 Progman，见 [`desktop`]），只在桌面可见；
//! - **渲染**：wry（WebView2）加载内嵌 HTML 卡片，数据以 `window.render(JSON)`
//!   注入；HTML 用 `prefers-color-scheme` 自动跟随系统明暗主题；
//! - **数据**：与主 app 同一份 `Documents\countdown-events.json`，天数计算
//!   复用 [`crate::api::countdown`]。每 2 秒轮询重建 payload，内容有变化才
//!   eval 到页面；行数变化时同步调整窗口高度。跨天由同一轮询兜底，无需
//!   单独定时器；
//! - **交互**：按住拖动换位置（系统移动循环），单击拉起主程序，右键菜单可
//!   退出；窗口位置记忆到 `%LOCALAPPDATA%\l78z\desktop-widget.json`；
//! - **自愈**：Explorer 重启后 WorkerW 失效，轮询里 `ensure_embedded` 重贴。

mod desktop;

use std::cell::RefCell;
use std::rc::Rc;
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};
use tao::dpi::{LogicalSize, PhysicalPosition};
use tao::event::{Event, StartCause, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoop};
use tao::platform::windows::WindowBuilderExtWindows;
use tao::window::WindowBuilder;
use windows_sys::Win32::Foundation::HWND;
use wry::WebViewBuilder;

use crate::api::countdown::{countdown_events, CountMode, CountdownEvent, FILE_NAME};

/// 卡片宽度（逻辑像素）。
const CARD_W: f64 = 300.0;
/// 卡片上下内边距。
const PAD_Y: f64 = 14.0;
/// 标题行高。
const TITLE_H: f64 = 26.0;
/// 每行列表行高（与 CSS line-height 对齐）。
const ROW_H: f64 = 24.0;
/// 最多显示行数；超出收成「…」一行。
const MAX_ROWS: usize = 8;
/// 数据轮询周期。
const POLL: Duration = Duration::from_secs(2);
/// 位置落盘节流。
const SAVE_THROTTLE: Duration = Duration::from_millis(500);

/// 注入页面的渲染数据。`rows` 每项是拼好的整行文本
/// （「128　　还剩 · 2026-12-20」），与 Android 部件 `buildListText` 同格式。
#[derive(Serialize)]
struct Payload {
    title: String,
    rows: Vec<String>,
    empty: String,
    menu_open: String,
    menu_quit: String,
}

/// 数据与文案状态。
struct State {
    path: String,
    zh: bool,
}

impl State {
    fn new() -> Self {
        let path = match dirs::document_dir() {
            Some(docs) => docs.join(FILE_NAME).to_string_lossy().into_owned(),
            // 文档目录都拿不到时退化成空路径——load_data 对不存在的文件
            // 返回空列表，部件显示空态即可，不该崩。
            None => String::new(),
        };
        Self {
            path,
            zh: desktop::system_is_zh(),
        }
    }

    fn payload(&self) -> Payload {
        let zh = self.zh;
        // countdown_events 已按「置顶优先、近者在前」排好序、天数算好。
        let events = countdown_events(self.path.clone()).unwrap_or_default();

        let total = events.len();
        // 放得下就全显示；放不下的收成前 MAX_ROWS-1 行加一行「…」。
        let cut = total > MAX_ROWS;
        let take = if cut { MAX_ROWS - 1 } else { total };
        let shown: Vec<&CountdownEvent> = events.iter().take(take).collect();

        let sep = if zh { "\u{3000}\u{3000}" } else { "  " };
        let mut rows: Vec<String> = shown.iter().map(|e| format_line(e, sep, zh)).collect();
        if cut {
            rows.push("…".to_string());
        }

        Payload {
            title: if zh { "倒数日" } else { "Countdowns" }.to_string(),
            rows,
            empty: if zh { "暂无倒数日" } else { "No countdowns yet" }.to_string(),
            menu_open: if zh { "打开互传助手" } else { "Open 互传助手" }.to_string(),
            menu_quit: if zh { "退出部件" } else { "Quit widget" }.to_string(),
        }
    }
}

/// 一行：「天数　　状态 · 日期」，与 Android `ListWidget.buildListText`
/// 逐字对应——两端部件说的是同一句话。
fn format_line(ev: &CountdownEvent, sep: &str, zh: bool) -> String {
    format!(
        "{days}{sep}{label} · {date}",
        days = abs_days(ev),
        sep = sep,
        label = status_label(ev, zh),
        date = ev.date,
    )
}

fn abs_days(ev: &CountdownEvent) -> i64 {
    ev.days_left.abs()
}

/// 状态词：还剩 / 已过 / 还有 / 距下次 / 就是今天。
///
/// 与 Dart `_statusLabel`、Kotlin `CountdownStore.statusLabel` 三方一致，
/// 改文案必须一起改。
fn status_label(ev: &CountdownEvent, zh: bool) -> &'static str {
    let (rem, passed, has, until_next, today) = if zh {
        ("还剩", "已过", "还有", "距下次", "就是今天")
    } else {
        ("Left", "Passed", "After", "Until next", "Today!")
    };
    let d = ev.days_left;
    match ev.mode {
        CountMode::Countdown => {
            if d > 0 {
                rem
            } else if d == 0 {
                today
            } else {
                passed
            }
        }
        CountMode::Countup => {
            if d < 0 {
                passed
            } else if d == 0 {
                today
            } else {
                has
            }
        }
        CountMode::Yearly => {
            if d > 0 {
                until_next
            } else {
                today
            }
        }
    }
}

/// 按行数算卡片高度（空态按一行算）。
fn height_for(rows: usize) -> f64 {
    PAD_Y * 2.0 + TITLE_H + ROW_H * rows.max(1) as f64
}

/// 窗口位置记忆。
struct LayoutState {
    pos: Option<(i32, i32)>,
    last_saved: Option<Instant>,
}

/// 落盘格式 `{ "x": .., "y": .. }`。**不能**直接反序列化成 `(i32, i32)`——
/// serde 的 tuple 要的是 JSON 数组，对象会解析失败、静默退回默认位置（实测踩坑）。
#[derive(Deserialize)]
struct SavedPos {
    x: i32,
    y: i32,
}

impl LayoutState {
    fn file() -> Option<std::path::PathBuf> {
        dirs::data_local_dir().map(|d| d.join("l78z").join("desktop-widget.json"))
    }

    fn load() -> Self {
        let pos = Self::file()
            .and_then(|f| std::fs::read_to_string(f).ok())
            .and_then(|t| serde_json::from_str::<SavedPos>(&t).ok())
            .map(|p| (p.x, p.y));
        Self {
            pos,
            last_saved: None,
        }
    }

    fn touch(&mut self, p: PhysicalPosition<i32>) {
        self.pos = Some((p.x, p.y));
    }

    /// 节流落盘：拖动过程中的 Moved 事件很密集，半秒写一次就够。
    fn maybe_save(&mut self) {
        let due = self
            .last_saved
            .map(|t| t.elapsed() >= SAVE_THROTTLE)
            .unwrap_or(true);
        if due {
            self.save();
        }
    }

    fn save(&mut self) {
        let (Some(pos), Some(file)) = (self.pos, Self::file()) else {
            return;
        };
        if let Some(dir) = file.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let json = serde_json::json!({ "x": pos.0, "y": pos.1 }).to_string();
        if std::fs::write(&file, json).is_ok() {
            crate::widget::desktop::log(&format!("位置已保存 ({}, {})", pos.0, pos.1));
            self.last_saved = Some(Instant::now());
        }
    }
}

/// 页面模板：CSS 圆角卡片画在透明窗口上，四角透出壁纸。
///
/// 占位段 `/*__INIT_JSON__*/null`（注释 + 默认值 null）整段换成真实 JSON：
/// 替换失败时页面拿到 null，render 抛错并回传宿主，日志里一眼可见。
fn page(init_json: &str) -> String {
    include_str!("widget.html").replace("/*__INIT_JSON__*/null", init_json)
}

/// 部件主流程。阻塞到退出。
pub fn run() {
    // 单实例：重复启动（设置页误点、自启+手开叠加）直接退出。
    let _instance = match desktop::single_instance() {
        Some(h) => h,
        None => return,
    };
    desktop::log_init();

    let state = State::new();
    let payload = state.payload();
    let init_json = serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string());
    // JSON 直接塞进 <script>，转义 `<` 防标题里的 `</script>` 提前闭合
    // （JSON 语法里不含 `<`，能被转义的只可能在字符串值内）。
    let init_json = init_json.replace('<', "\\u003c");
    desktop::log(&format!(
        "启动 data='{}' zh={} rows={} json={init_json}",
        state.path,
        state.zh,
        payload.rows.len(),
    ));

    let layout = Rc::new(RefCell::new(LayoutState::load()));

    let event_loop = EventLoop::new();
    let mut window_builder = WindowBuilder::new()
        .with_title("互传助手 · 倒数日")
        .with_decorations(false)
        .with_transparent(true)
        .with_resizable(false)
        .with_skip_taskbar(true)
        // 关掉「无边框窗口阴影内边距」：tao 默认会给无边框窗口四周留
        // 阴影占位（Win11 实测左/右/下 12px、上 2px），由 DWM 透明合成；
        // 嵌进 Progman 后 DWM 不再绘制，占位区露出黑底（实测黑边元凶）。
        .with_undecorated_shadow(false)
        .with_inner_size(LogicalSize::new(CARD_W, height_for(payload.rows.len())));
    if let Some((x, y)) = layout.borrow().pos {
        window_builder = window_builder.with_position(PhysicalPosition::new(x, y));
    }
    let window = window_builder
        .build(&event_loop)
        .expect("创建部件窗口失败");

    let hwnd = raw_hwnd(&window);
    let size = window.inner_size();
    desktop::log(&format!(
        "窗口 hwnd=0x{:X} inner={}x{} physical (期望 450x117 @150%)",
        hwnd as usize,
        size.width,
        size.height
    ));
    desktop::set_noactivate(hwnd);
    desktop::embed(hwnd);

    let html = page(&init_json);
    // 占位符没被替换掉的话，页面会用默认空对象渲染（什么都看不见）——
    // 留一份 HTML 到日志目录，出问题直接翻。
    if html.contains("__INIT_JSON__") {
        desktop::log("警告: 初始 JSON 占位符未被替换!");
    }
    if let Some(dir) = desktop::log_file().and_then(|f| f.parent().map(|p| p.to_path_buf())) {
        let _ = std::fs::write(dir.join("widget-page.html"), &html);
    }

    let ipc_layout = Rc::clone(&layout);
    let webview = WebViewBuilder::new()
        .with_html(html)
        .with_transparent(true)
        .with_ipc_handler(move |req| {
            // 页面发来的都是 JSON 字符串字面量（"drag"），两边引号一起去掉。
            let body = req.body().trim().trim_matches('"').to_string();
            desktop::log(&format!("IPC: {body}"));
            match body.as_str() {
                "drag" => desktop::begin_drag(hwnd),
                "open" => desktop::open_main_app(),
                "quit" => {
                    ipc_layout.borrow_mut().save();
                    std::process::exit(0);
                }
                _ => {}
            }
        })
        .build(&window)
        .expect("创建 WebView 失败");
    desktop::log("WebView 已创建，进入事件循环");

    // 初始 payload 已随 HTML 注入并渲染；从第二次起靠轮询 diff。
    let mut last_json = init_json;
    let mut last_rows = payload.rows.len();
    let mut next_tick = Instant::now() + POLL;

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::WaitUntil(next_tick);
        match event {
            // 周期任务：重读数据、探测 Explorer 重启。
            Event::NewEvents(StartCause::ResumeTimeReached { .. }) => {
                next_tick = Instant::now() + POLL;

                let p = state.payload();
                let json = serde_json::to_string(&p).unwrap_or_default();
                let changed = json != last_json;
                desktop::log(&format!(
                    "tick rows={} changed={}",
                    p.rows.len(),
                    changed
                ));
                if changed {
                    if p.rows.len() != last_rows {
                        let _ = window
                            .set_inner_size(LogicalSize::new(CARD_W, height_for(p.rows.len())));
                        last_rows = p.rows.len();
                    }
                    let _ = webview.evaluate_script(&format!("window.render({json})"));
                    last_json = json;
                }
                desktop::ensure_embedded(hwnd);
            }

            Event::WindowEvent { event, .. } => match event {
                WindowEvent::Moved(pos) => {
                    let mut l = layout.borrow_mut();
                    l.touch(pos);
                    l.maybe_save(); // 落盘时自带日志
                }
                WindowEvent::Resized(size) => {
                    desktop::log(&format!("Resized to {}x{}", size.width, size.height));
                }
                // 部件没有关闭入口（右键菜单走 IPC），出现即视为该退了——
                // 这也是「进程无故消失」唯一会留痕的路径，必须记。
                WindowEvent::CloseRequested => {
                    desktop::log("收到 CloseRequested，退出");
                    layout.borrow_mut().save();
                    *control_flow = ControlFlow::Exit;
                }
                WindowEvent::Destroyed => {
                    desktop::log("窗口已销毁");
                }
                _ => {}
            },
            _ => {}
        }
    });
}

/// 取 HWND（tao 窗口的原始句柄）。
fn raw_hwnd(window: &tao::window::Window) -> HWND {
    use raw_window_handle::{HasWindowHandle, RawWindowHandle};
    match window.window_handle().expect("无窗口句柄").as_raw() {
        RawWindowHandle::Win32(h) => h.hwnd.get() as HWND,
        _ => std::ptr::null_mut(),
    }
}
