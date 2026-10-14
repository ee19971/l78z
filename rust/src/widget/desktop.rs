//! 桌面部件的 Win32 底层细节：贴桌面层、拖动、拉起主程序、单实例。
//!
//! 贴桌面用的是 Rainmeter 同款技术：向 Explorer 的 Progman 发 0x052C 让
//! shell 生成 WorkerW 层，再把部件窗口 SetParent 进去——部件于是只在
//! 桌面可见（被普通窗口盖住、全屏应用下自然隐藏），语义与 Android
//! 桌面部件一致。Explorer 重启后 WorkerW 会消失，由调用方周期性
//! `ensure_embedded` 自愈。
#![cfg(windows)]

use std::ptr;
use std::sync::atomic::{AtomicIsize, Ordering};

use windows_sys::Win32::Foundation::{GetLastError, HANDLE, HWND, ERROR_ALREADY_EXISTS};
use windows_sys::Win32::Globalization::GetUserDefaultUILanguage;
use windows_sys::Win32::System::Console::{GetStdHandle, STD_ERROR_HANDLE};
use windows_sys::Win32::System::Threading::CreateMutexW;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::ReleaseCapture;
use windows_sys::Win32::UI::Shell::ShellExecuteW;
use windows_sys::Win32::UI::WindowsAndMessaging::{
    FindWindowExW, FindWindowW, GetAncestor, GetWindowLongPtrW, IsWindow, SendMessageTimeoutW,
    SendMessageW, SetParent, SetWindowLongPtrW, GWL_EXSTYLE, SMTO_NORMAL, SW_SHOWNORMAL,
    WM_NCLBUTTONDOWN, WS_EX_NOACTIVATE,
};

/// 缓存的 WorkerW 句柄；Explorer 重启后该句柄失效，`ensure_embedded` 据此发现并重贴。
static WORKERW: AtomicIsize = AtomicIsize::new(0);

/// UTF-16 宽字符串（Win32 的 `*W` API 一律要这个），末尾带 NUL。
fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(Some(0)).collect()
}

// ---------------------------------------------------------------------------
// 日志：release 版是 windows_subsystem（无控制台），出问题全靠这个文件。
// 启动时截断，避免无限膨胀。
// ---------------------------------------------------------------------------

/// 日志文件路径 `%LOCALAPPDATA%\l78z\desktop-widget.log`。
pub fn log_file() -> Option<std::path::PathBuf> {
    Some(dirs::data_local_dir()?.join("l78z").join("desktop-widget.log"))
}

/// 启动时截断旧日志。
pub fn log_init() {
    if let Some(f) = log_file() {
        if let Some(dir) = f.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::write(&f, "");
    }
}

/// stderr 是否可用，探测一次后缓存。
///
/// 部件是 windows_subsystem=windows 的 GUI 程序：**设置开关的
/// `ProcessStartMode.detached` 和注册表 Run 键拉起时，stderr 句柄是
/// NULL，`eprintln!` 会直接 panic（"failed printing to stderr"），
/// 部件开局第一行日志就死**。只有从带控制台/管道的环境启动（如
/// pwsh 直跑、重定向调试）才有 stderr。
fn stderr_available() -> bool {
    use std::sync::atomic::{AtomicU8, Ordering};
    // 0=未探测 1=可用 2=不可用
    static STATE: AtomicU8 = AtomicU8::new(0);
    match STATE.load(Ordering::Relaxed) {
        1 => true,
        2 => false,
        _ => {
            let ok = unsafe {
                let h = GetStdHandle(STD_ERROR_HANDLE);
                !h.is_null() && h as isize != -1 // NULL 或 INVALID_HANDLE_VALUE
            };
            STATE.store(if ok { 1 } else { 2 }, Ordering::Relaxed);
            ok
        }
    }
}

/// 追加一行日志（带时间戳，失败静默——日志绝不能把部件弄崩）。
pub fn log(msg: &str) {
    use std::io::Write;
    if stderr_available() {
        eprintln!("[widget] {msg}"); // 带控制台/管道启动时顺带打一份
    }
    if let Some(f) = log_file() {
        if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open(&f) {
            let _ = writeln!(file, "{} {msg}", chrono::Local::now().format("%H:%M:%S%.3f"));
        }
    }
}

/// 部件进程全局单实例。
///
/// 返回 `Some(handle)` 表示拿到了锁（句柄保持打开到进程结束即为锁）；
/// 返回 `None` 表示已有实例在跑或创建失败，调用方应直接退出。
pub fn single_instance() -> Option<HANDLE> {
    unsafe {
        let name = wide("Local\\l78z_desktop_widget");
        let handle = CreateMutexW(ptr::null(), 0, name.as_ptr());
        if handle.is_null() {
            return None;
        }
        if GetLastError() == ERROR_ALREADY_EXISTS {
            None
        } else {
            Some(handle)
        }
    }
}

/// 找桌面层窗口：宿主部件的目标父窗口（含 SHELLDLL_DefView 的 WorkerW）。
///
/// 0x052C 是个「开关」（Win11 26H2 实测）：DefView 在 Progman 里时发一次会把它
/// 挪进新 WorkerW；已经在 WorkerW 里再发反而挪回 Progman。所以顺序是
/// **先查现状，只在 DefView 还在 Progman 时才发一次**，绝不多发。
///
/// 都找不到返回空指针（Explorer 正在重启等罕见时机），调用方下个周期重试。
fn find_workerw() -> HWND {
    unsafe {
        let defview_cls = wide("SHELLDLL_DefView");
        let worker_cls = wide("WorkerW");

        // 1. 经典结构：DefView 已在某个 WorkerW 里（或上一轮 0x052C 挪过去的）。
        if let Some(w) = workerw_with_defview(&defview_cls, &worker_cls) {
            return w;
        }

        // 2. DefView 在 Progman 里 → 发一次 0x052C 让 shell 挪进新 WorkerW。
        let progman = FindWindowW(wide("Progman").as_ptr(), ptr::null());
        if progman.is_null() {
            return ptr::null_mut();
        }
        if !FindWindowExW(progman, ptr::null_mut(), defview_cls.as_ptr(), ptr::null()).is_null() {
            SendMessageTimeoutW(progman, 0x052C, 0, 0, SMTO_NORMAL, 1000, ptr::null_mut());
            if let Some(w) = workerw_with_defview(&defview_cls, &worker_cls) {
                return w;
            }
            // 0x052C 被新版 shell 忽略：Progman 本身就是桌面层，直接嵌它。
            log(&format!("find: 0x052C 后 DefView 仍在 Progman 0x{:X}，嵌 Progman", progman as usize));
            return progman;
        }
        // 3. Progman 也找不到（极端：shell 正在重建），下个周期重试。
        ptr::null_mut()
    }
}

/// 遍历顶层 WorkerW，返回含 SHELLDLL_DefView 的那个。
///
/// # Safety
/// 调用方需在 unsafe 上下文里；两个参数是 wide() 出来的 NUL 结尾宽字符串。
unsafe fn workerw_with_defview(defview_cls: &[u16], worker_cls: &[u16]) -> Option<HWND> {
    let mut w: HWND = ptr::null_mut();
    loop {
        w = FindWindowExW(ptr::null_mut(), w, worker_cls.as_ptr(), ptr::null());
        if w.is_null() {
            return None;
        }
        if !FindWindowExW(w, ptr::null_mut(), defview_cls.as_ptr(), ptr::null()).is_null() {
            return Some(w);
        }
    }
}

/// 取真实父窗口。
///
/// 不能用 GetParent——部件窗口是 WS_POPUP（无 WS_CHILD 样式）经 SetParent
/// 挂进桌面层的，GetParent 对这种「有父但没 WS_CHILD 样」的窗口返回 NULL
/// （假阴性，实测踩坑）；GetAncestor(GA_PARENT) 返回真实父句柄。
fn parent_of(hwnd: HWND) -> HWND {
    unsafe { GetAncestor(hwnd, 1 /* GA_PARENT */) }
}

/// 把窗口嵌进桌面层（含 SHELLDLL_DefView 的 WorkerW，或新系统上的 Progman）：
/// 部件显示在壁纸之上、桌面图标之上、普通窗口之下。
pub fn embed(hwnd: HWND) {
    unsafe {
        let workerw = find_workerw();
        if workerw.is_null() {
            // Explorer 重启中之类的一时性失败，留给下个周期重试。
            log("embed: 暂时找不到桌面层（WorkerW/Progman），下个周期重试");
            return;
        }
        let before = parent_of(hwnd);
        let ret = if before == workerw {
            workerw
        } else {
            SetParent(hwnd, workerw)
        };
        let after = parent_of(hwnd);
        if after == workerw {
            log(&format!(
                "embed: OK desktop=0x{:X} hwnd=0x{:X} ret=0x{:X}",
                workerw as usize,
                hwnd as usize,
                ret as usize,
            ));
        } else {
            // 失败时 SetParent 返回 0，GetLastError 是关键线索
            // （1400=句柄无效 / 5=权限 / 其它=结构差异）。
            log(&format!(
                "embed: 失败 desktop=0x{:X} hwnd=0x{:X} ret=0x{:X} err={} (前parent=0x{:X})",
                workerw as usize,
                hwnd as usize,
                ret as usize,
                GetLastError(),
                before as usize,
            ));
            return; // 没贴上就别更新缓存，下个周期整体重试
        }
        WORKERW.store(workerw as isize, Ordering::Relaxed);
    }
}

/// 自愈：缓存的桌面层没了（Explorer 重启）或父关系变了，重新贴一次。
/// 成功嵌入后的每次调用只花两个系统查询，不再重发 0x052C。
pub fn ensure_embedded(hwnd: HWND) {
    unsafe {
        let cached = WORKERW.load(Ordering::Relaxed) as HWND;
        if cached.is_null() || IsWindow(cached) == 0 || parent_of(hwnd) != cached {
            embed(hwnd);
        }
    }
}

/// 让系统接管窗口移动（拖动部件换位置）。
///
/// IPC 回调里同步调用会阻塞到用户松手为止，这正是想要的：
/// 移动循环期间网页收不到鼠标事件，松手后回调返回。
pub fn begin_drag(hwnd: HWND) {
    unsafe {
        ReleaseCapture();
        SendMessageW(hwnd, WM_NCLBUTTONDOWN, 2 /* HTCAPTION */, 0);
    }
}

/// 点击部件时拉起主程序（与部件同目录的 l78z.exe）。
pub fn open_main_app() {
    let Some(exe) = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.join("l78z.exe")))
    else {
        return;
    };
    if !exe.exists() {
        // 开发期直接跑 target 下的部件 exe 时没有同目录主程序，静默跳过。
        return;
    }
    let op = wide("open");
    let file: Vec<u16> = exe.to_string_lossy().encode_utf16().chain(Some(0)).collect();
    unsafe {
        ShellExecuteW(
            ptr::null_mut(),
            op.as_ptr(),
            file.as_ptr(),
            ptr::null(),
            ptr::null(),
            SW_SHOWNORMAL,
        );
    }
}

/// 加 WS_EX_NOACTIVATE：点击部件不抢焦点，不进 Alt+Tab（配合 tao 的
/// skip_taskbar），免得桌面上点一下部件把正在用的窗口弄失焦。
pub fn set_noactivate(hwnd: HWND) {
    unsafe {
        let ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
        SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE as isize);
    }
}

/// 系统 UI 语言是否中文（部件文案跟系统语言，与 Android 部件一致地
/// 不依赖应用内语言设置）。
pub fn system_is_zh() -> bool {
    unsafe { (GetUserDefaultUILanguage() & 0x3FF) == 0x04 } // LANG_CHINESE
}
