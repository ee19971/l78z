use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use axum::body::Body;
use axum::extract::{DefaultBodyLimit, State};
use axum::http::{HeaderMap, StatusCode};
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use crate::frb_generated::StreamSink;
use futures_util::StreamExt;
use rand::Rng;
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;
use tokio::task::JoinHandle;
use tokio_util::io::ReaderStream;

use crate::util::net;

pub const DEFAULT_PORT: u16 = 8787;

/// 对端连接信息（也作为二维码内容序列化）。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectInfo {
    pub name: String,
    pub ip: String,
    pub port: u16,
    pub token: String,
    /// 备选局域网 IP。对端可能是多网卡机器（同时开着 WSL/虚拟机网卡很常见），
    /// 单个 ip 未必可达，发送端会按顺序逐个尝试。
    /// 旧版二维码没有该字段，故用 default 兼容。
    #[serde(default)]
    pub ips: Vec<String>,
}

/// 接收端推送事件。
#[derive(Debug, Clone, Serialize)]
pub enum TransferEvent {
    TextReceived {
        from: String,
        kind: String,
        text: String,
    },
    FileReceived {
        from: String,
        name: String,
        path: String,
        size: u64,
    },
    /// 对端把自己的连接信息注册了过来（双向配对）。
    ///
    /// 只扫对方的码是单向的：只有扫码方知道对方地址，被扫方一无所知，
    /// 结果就是"扫码的那台能发，被扫的那台发不了"。补一次注册即可双向互通。
    PeerRegistered {
        info: ConnectInfo,
    },
    ServerStarted {
        port: u16,
    },
    ServerStopped,
}

/// 文件发送进度。
#[derive(Debug, Clone, Serialize)]
pub struct SendProgress {
    pub sent_bytes: u64,
    pub total_bytes: u64,
}

#[derive(Debug, Deserialize)]
struct TextReq {
    token: String,
    #[serde(default)]
    from: String,
    #[serde(default = "default_kind")]
    kind: String,
    text: String,
}

fn default_kind() -> String {
    "manual".to_string()
}

/// 反向注册请求：调用方把自己的 ConnectInfo 交给对端，让对方也能反向发送。
#[derive(Debug, Deserialize)]
struct HelloReq {
    token: String,
    info: ConnectInfo,
}

#[derive(Clone)]
struct AppState {
    token: String,
    device_name: String,
    save_dir: PathBuf,
    events: broadcast::Sender<TransferEvent>,
}

struct ServerHandle {
    abort: JoinHandle<()>,
}

pub(crate) fn runtime() -> &'static tokio::runtime::Runtime {
    static RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
    RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("failed to build tokio runtime")
    })
}

fn server_cell() -> &'static Mutex<Option<ServerHandle>> {
    static CELL: OnceLock<Mutex<Option<ServerHandle>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(None))
}

fn events_tx() -> &'static broadcast::Sender<TransferEvent> {
    static TX: OnceLock<broadcast::Sender<TransferEvent>> = OnceLock::new();
    TX.get_or_init(|| broadcast::channel(64).0)
}

fn new_token() -> String {
    let mut rng = rand::rng();
    let a: u64 = rng.random();
    let b: u64 = rng.random();
    format!("{a:016x}{b:016x}")
}

pub(crate) fn sanitize_filename(name: &str) -> String {
    let base = Path::new(name)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();
    let cleaned: String = base
        .chars()
        .map(|c| if c.is_control() { '_' } else { c })
        .collect();
    if cleaned.is_empty() {
        "file.bin".to_string()
    } else {
        cleaned
    }
}

/// 把任意文本 percent-encode 成纯 ASCII。
///
/// header 的值必须是可见 ASCII。中文等 UTF-8 字节虽然落在 RFC 3986 的
/// obs-text 区间、hyper 也允许原样存放，但对端用 `to_str()` 解析时会
/// 直接判为非法，表现就是文件名整个丢掉、落成 `file.bin`。收发两端统一
/// 走 %XX 转义，谁都不用再关心字符集。
fn percent_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.as_bytes() {
        match b {
            // unreserved，保持可读，日志里也能直接看出原始名字
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*b as char)
            }
            _ => {
                out.push('%');
                out.push_str(&format!("{b:02X}"));
            }
        }
    }
    out
}

/// 十六进制字符转数值。
fn hex_val(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

/// percent-decode。
///
/// 对端不一定是本应用，收到什么都有可能：转义不完整的、非法十六进制的、
/// 甚至根本没转义的 UTF-8。解不出的部分按原样保留，绝不能 panic ——
/// 文件名难看点可以接受，把整个文件传输搞崩不行。
fn percent_decode(s: &str) -> String {
    let raw = s.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(raw.len());
    let mut i = 0;
    while i < raw.len() {
        if raw[i] != b'%' {
            out.push(raw[i]);
            i += 1;
            continue;
        }
        // %XX 需要紧跟两个十六进制位，缺位或非法就只吃掉 %
        if i + 2 < raw.len() {
            if let (Some(h), Some(l)) = (hex_val(raw[i + 1]), hex_val(raw[i + 2])) {
                out.push(h << 4 | l);
                i += 3;
                continue;
            }
        }
        out.push(b'%');
        i += 1;
    }
    // 非法 UTF-8 序列（比如只剩半个汉字）替换成替换符而不是报错
    String::from_utf8_lossy(&out).into_owned()
}

/// 取 header 的原始字节，按 UTF-8 尽力还原。
///
/// 刻意不用 `to_str()`：它要求可见 ASCII，会把未转义的 UTF-8 一律判成
/// 非法，直接导致文件名、发送方名称被丢弃。改按字节解码后，最坏结果
/// 只是名字不好看，而不是整个字段凭空消失。
fn header_raw(headers: &HeaderMap, key: &str) -> Option<String> {
    headers
        .get(key)
        .map(|v| String::from_utf8_lossy(v.as_bytes()).into_owned())
}

pub(crate) fn unique_path(dir: &Path, name: &str) -> PathBuf {
    let p = dir.join(name);
    if !p.exists() {
        return p;
    }
    let stem = Path::new(name)
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "file".to_string());
    let ext = Path::new(name)
        .extension()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();
    for i in 1..10_000 {
        let candidate = if ext.is_empty() {
            dir.join(format!("{stem}_{i}"))
        } else {
            dir.join(format!("{stem}_{i}.{ext}"))
        };
        if !candidate.exists() {
            return candidate;
        }
    }
    dir.join(format!("{stem}_{}", std::process::id()))
}

async fn health(State(st): State<AppState>) -> impl IntoResponse {
    Json(serde_json::json!({ "ok": true, "name": st.device_name }))
}

async fn send_text(
    State(st): State<AppState>,
    Json(req): Json<TextReq>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    if req.token != st.token {
        return Err((StatusCode::FORBIDDEN, "invalid token".to_string()));
    }
    let _ = st.events.send(TransferEvent::TextReceived {
        from: req.from,
        kind: req.kind,
        text: req.text,
    });
    Ok(Json(serde_json::json!({ "ok": true })))
}

/// 反向注册：把调用方的连接信息保存到本端，让本端也能向它发送。
async fn hello(
    State(st): State<AppState>,
    Json(req): Json<HelloReq>,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    if req.token != st.token {
        return Err((StatusCode::FORBIDDEN, "invalid token".to_string()));
    }
    if req.info.ip.is_empty() || req.info.port == 0 {
        return Err((StatusCode::BAD_REQUEST, "注册信息缺少可用地址".to_string()));
    }
    let _ = st.events.send(TransferEvent::PeerRegistered { info: req.info });
    Ok(Json(serde_json::json!({ "ok": true, "name": st.device_name })))
}

async fn upload_file(
    State(st): State<AppState>,
    headers: HeaderMap,
    body: Body,
) -> Result<impl IntoResponse, (StatusCode, String)> {
    let token = headers
        .get("x-l78z-token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if token != st.token {
        return Err((StatusCode::FORBIDDEN, "invalid token".to_string()));
    }
    let from = header_raw(&headers, "x-l78z-from")
        .map(|v| percent_decode(&v))
        .unwrap_or_default();
    // 对端可能是旧版本或第三方实现，没转义的也照收：header_raw 已按字节
    // 解码，percent_decode 对没有 % 的内容是恒等的，只是兜底不再用 file.bin
    // 直接盖掉真实名字。
    let raw_name = header_raw(&headers, "x-l78z-filename");
    let name = sanitize_filename(&percent_decode(raw_name.as_deref().unwrap_or("file.bin")));

    tokio::fs::create_dir_all(&st.save_dir)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    let path = unique_path(&st.save_dir, &name);

    let mut file = tokio::fs::File::create(&path)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    let mut stream = body.into_data_stream();
    let mut size: u64 = 0;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
        tokio::io::AsyncWriteExt::write_all(&mut file, &chunk)
            .await
            .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
        size += chunk.len() as u64;
    }
    drop(file);

    let _ = st.events.send(TransferEvent::FileReceived {
        from,
        name,
        path: path.to_string_lossy().into_owned(),
        size,
    });
    Ok(Json(serde_json::json!({ "ok": true, "size": size })))
}

fn build_router(state: AppState) -> Router {
    Router::new()
        .route("/api/v1/health", get(health))
        .route("/api/v1/text", post(send_text))
        .route("/api/v1/file", post(upload_file))
        .route("/api/v1/hello", post(hello))
        .layer(DefaultBodyLimit::max(4 * 1024 * 1024 * 1024))
        .with_state(state)
}

/// 启动接收服务器，返回本机连接信息（可直接生成二维码）。
pub fn server_start(port_hint: u16, save_dir: String, device_name: String) -> anyhow::Result<ConnectInfo> {
    server_stop().ok();

    let candidates = net::lan_ipv4_candidates();
    let primary = candidates
        .first()
        .ok_or_else(|| anyhow::anyhow!("未找到可用的局域网 IPv4 地址"))?
        .to_string();
    // 二维码里带上备选地址（主地址 ip 已含，这里只放额外候选，上限 3 个，
    // 避免二维码过大影响识别）
    let ips: Vec<String> = candidates
        .iter()
        .skip(1)
        .take(3)
        .map(|v4| v4.to_string())
        .collect();
    let token = new_token();
    let events_for_state = events_tx().clone();
    let state = AppState {
        token: token.clone(),
        device_name: device_name.clone(),
        save_dir: PathBuf::from(&save_dir),
        events: events_for_state,
    };
    let router = build_router(state);

    let addr: std::net::SocketAddr = format!("0.0.0.0:{port_hint}").parse()?;
    let listener = std::net::TcpListener::bind(addr).or_else(|_| {
        std::net::TcpListener::bind(("0.0.0.0", 0))
    })?;
    listener.set_nonblocking(true)?;
    let port = listener.local_addr()?.port();

    let abort = runtime().spawn(async move {
        let listener = tokio::net::TcpListener::from_std(listener).expect("tcp listener");
        let _ = events_tx().send(TransferEvent::ServerStarted { port });
        let _ = axum::serve(listener, router).await;
        let _ = events_tx().send(TransferEvent::ServerStopped);
    });

    *server_cell().lock().unwrap() = Some(ServerHandle { abort });

    Ok(ConnectInfo {
        name: device_name,
        ip: primary,
        port,
        token,
        ips,
    })
}

/// 停止接收服务器。
pub fn server_stop() -> anyhow::Result<()> {
    if let Some(handle) = server_cell().lock().unwrap().take() {
        handle.abort.abort();
    }
    Ok(())
}

/// 订阅服务器事件流（收到文本/文件时推送给 Dart）。
pub fn server_events(sink: StreamSink<TransferEvent>) {
    let mut rx = events_tx().subscribe();
    runtime().spawn(async move {
        loop {
            match rx.recv().await {
                Ok(ev) => {
                    if sink.add(ev).is_err() {
                        break;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    });
}

/// 把 ConnectInfo 序列化为配对二维码内容。
pub fn make_pairing_payload(info: ConnectInfo) -> anyhow::Result<String> {
    serde_json::to_string(&info).map_err(|e| anyhow::anyhow!(e))
}

/// 解析配对二维码内容；不是配对信息则返回 None。
pub fn parse_connect_info(text: String) -> Option<ConnectInfo> {
    let v: serde_json::Value = serde_json::from_str(&text).ok()?;
    let info: ConnectInfo = serde_json::from_value(v).ok()?;
    if info.ip.is_empty() || info.token.is_empty() || info.port == 0 {
        return None;
    }
    Some(info)
}

/// 依优先级返回待尝试的对端 IP（`ip` 恒排第一，整体去重）。
fn candidate_ips(info: &ConnectInfo) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for s in std::iter::once(&info.ip).chain(info.ips.iter()) {
        if !s.is_empty() && !out.contains(s) {
            out.push(s.clone());
        }
    }
    out
}

fn http_detail(status: reqwest::StatusCode, body: String) -> String {
    let body = body.trim();
    if body.is_empty() {
        format!("HTTP {status}")
    } else {
        format!("HTTP {status} {body}")
    }
}

/// 探测对端可达地址：逐个候选 IP 访问健康检查接口，
/// 返回第一个正常响应的 IP；全部不可达返回 None。
///
/// 用于配对后立即验证"扫到的码到底通不通"，以及文件发送前选路。
pub async fn client_probe(info: ConnectInfo) -> Option<String> {
    let client = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(3))
        .timeout(std::time::Duration::from_secs(4))
        .build()
        .ok()?;
    for ip in candidate_ips(&info) {
        let url = format!("http://{ip}:{}/api/v1/health", info.port);
        if let Ok(resp) = client.get(&url).send().await {
            if resp.status().is_success() {
                return Some(ip);
            }
        }
    }
    None
}

/// 发送文本到对端（多地址自动回退）。
pub async fn client_send_text(info: ConnectInfo, text: String, kind: String, from: String) -> anyhow::Result<()> {
    let client = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(30))
        .build()?;

    let ips = candidate_ips(&info);
    let mut last_err: Option<anyhow::Error> = None;

    for ip in &ips {
        let url = format!("http://{ip}:{}/api/v1/text", info.port);
        match client
            .post(&url)
            .json(&serde_json::json!({
                "token": &info.token,
                "from": &from,
                "kind": &kind,
                "text": &text,
            }))
            .send()
            .await
        {
            // send() 返回 Err 表示压根没拿到 HTTP 响应，换下一个地址是安全的
            Err(e) => last_err = Some(anyhow::Error::new(e)),
            Ok(resp) => {
                let status = resp.status();
                if status.is_success() {
                    return Ok(());
                }
                // 对端有响应：说明地址是对的，问题出在别处（token 过期等），不再换地址
                let body = resp.text().await.unwrap_or_default();
                anyhow::bail!("发送失败: {}", http_detail(status, body));
            }
        }
    }

    let detail = last_err
        .map(|e| e.to_string())
        .unwrap_or_else(|| "连接被拒绝或超时".to_string());
    Err(anyhow::anyhow!(
        "无法连接到对端 {}:{}（已尝试 {}）: {}",
        info.name,
        info.port,
        ips.join(", "),
        detail
    ))
}

/// 把本机连接信息注册给对端，让对方也能反向发送。
///
/// 只扫对方的二维码是单向的——对方并不知道本机地址，所以"扫别人的那台能发、
/// 被扫的那台发不了"。配对成功后补调一次本接口即可双向互通。
///
/// 对端没启动接收服务时会失败，调用方据此提示用户。
pub async fn client_hello(info: ConnectInfo, self_info: ConnectInfo) -> anyhow::Result<()> {
    let client = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(15))
        .build()?;

    let ips = candidate_ips(&info);
    let mut last_err: Option<anyhow::Error> = None;

    for ip in &ips {
        let url = format!("http://{ip}:{}/api/v1/hello", info.port);
        match client
            .post(&url)
            .json(&serde_json::json!({
                "token": &info.token,
                "info": &self_info,
            }))
            .send()
            .await
        {
            Err(e) => last_err = Some(anyhow::Error::new(e)),
            Ok(resp) => {
                let status = resp.status();
                if status.is_success() {
                    return Ok(());
                }
                let body = resp.text().await.unwrap_or_default();
                anyhow::bail!("注册失败: {}", http_detail(status, body));
            }
        }
    }

    let detail = last_err
        .map(|e| e.to_string())
        .unwrap_or_else(|| "连接被拒绝或超时".to_string());
    Err(anyhow::anyhow!(
        "无法连接到对端 {}:{}（已尝试 {}）: {}。对方需要先启动接收服务，才能反向发送",
        info.name,
        info.port,
        ips.join(", "),
        detail
    ))
}

/// 发送文件到对端（流式上传，带进度）。
pub async fn client_send_file(
    info: ConnectInfo,
    path: String,
    from: String,
    sink: StreamSink<SendProgress>,
) -> anyhow::Result<()> {
    let src = PathBuf::from(&path);
    let meta = tokio::fs::metadata(&src).await?;
    anyhow::ensure!(meta.is_file(), "不是有效文件: {path}");
    let total = meta.len();
    let filename = src
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "file.bin".to_string());

    let file = tokio::fs::File::open(&src).await?;

    // 多网卡对端（虚拟网卡地址）必然连不上：先挑一个真正可达的地址再上传，
    // 避免传到一半才发现走错网卡。
    let ip = client_probe(info.clone()).await.ok_or_else(|| {
        anyhow::anyhow!(
            "无法连接到对端 {}:{}（已尝试 {}）。请确认两台设备在同一局域网，且对方已启动接收服务",
            info.name,
            info.port,
            candidate_ips(&info).join(", ")
        )
    })?;

    let counter = Arc::new(AtomicU64::new(0));
    let counter2 = counter.clone();
    let stream = ReaderStream::new(file).inspect(move |chunk| {
        if let Ok(bytes) = chunk {
            counter2.fetch_add(bytes.len() as u64, Ordering::Relaxed);
        }
    });
    let body = Body::from_stream(stream);

    let url = format!("http://{}:{}/api/v1/file", ip, info.port);
    let client = reqwest::Client::builder()
        .connect_timeout(std::time::Duration::from_secs(5))
        .timeout(std::time::Duration::from_secs(600))
        .build()?;

    let progress_sink = sink;
    let prog = tokio::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_millis(120)).await;
            let sent = counter.load(Ordering::Relaxed);
            if progress_sink
                .add(SendProgress {
                    sent_bytes: sent,
                    total_bytes: total,
                })
                .is_err()
            {
                break;
            }
            if sent >= total && total > 0 {
                break;
            }
        }
    });

    let resp = client
        .post(&url)
        .header("x-l78z-token", &info.token)
        // 文件名和发送方名称都可能含中文，必须转义成纯 ASCII——
        // HTTP header 不允许非 ASCII，不转义的话对端解析直接失败，
        // 文件名会整个丢掉、落成 file.bin。
        .header("x-l78z-from", percent_encode(&from))
        .header("x-l78z-filename", percent_encode(&filename))
        .header(reqwest::header::CONTENT_LENGTH, total)
        .body(convert_body(body))
        .send()
        .await;

    prog.abort();
    let resp = resp?;
    let status = resp.status();
    if !status.is_success() {
        let body = resp.text().await.unwrap_or_default();
        anyhow::bail!("文件发送失败: {}", http_detail(status, body));
    }
    Ok(())
}

/// reqwest Body 与 axum Body 类型不同，这里做流转换。
fn convert_body(body: Body) -> reqwest::Body {
    let stream = body.into_data_stream().map(|chunk| {
        chunk.map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))
    });
    reqwest::Body::wrap_stream(stream)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;

    /// 全局只有一个 server 句柄，多个测试并发跑会互相把它停掉，
    /// 因此所有会起服务的测试都先抢这把锁串行执行。
    fn server_lock() -> std::sync::MutexGuard<'static, ()> {
        static L: OnceLock<std::sync::Mutex<()>> = OnceLock::new();
        L.get_or_init(|| std::sync::Mutex::new(()))
            .lock()
            .unwrap_or_else(|e| e.into_inner())
    }

    #[test]
    fn percent_encoding_produces_ascii_only() {
        // 非 ASCII 的 header 值对端根本解析不出来，这是整套转义存在的理由。
        let enc = percent_encode("年度报告（终稿）.docx");
        assert!(enc.is_ascii(), "编码结果必须是纯 ASCII: {enc}");
        // unreserved 字符不转义，日志里才看得出原本叫什么
        assert_eq!(percent_encode("A-z_0.9~"), "A-z_0.9~");
    }

    #[test]
    fn percent_roundtrip_keeps_chinese_filename() {
        for name in [
            "年度报告 2026（终稿）.docx",
            "照片.jpg",
            "a-b_c.1~2.txt",
            "emoji🙂.png",
        ] {
            assert_eq!(percent_decode(&percent_encode(name)), name, "{name}");
        }
    }

    #[test]
    fn percent_decode_tolerates_malformed_input() {
        // 对端不一定是本应用，坏输入只能原样保留，绝不能 panic——
        // 文件名难看可以接受，把整个传输搞崩不行。
        assert_eq!(percent_decode("plain.txt"), "plain.txt");
        assert_eq!(percent_decode("%"), "%");
        assert_eq!(percent_decode("100%"), "100%");
        assert_eq!(percent_decode("%zz"), "%zz");
        // %E0%A4 是个不完整的三字节序列，落到非 UTF-8 上
        assert_eq!(percent_decode("%E0%A4"), "\u{FFFD}");
    }

    /// 复现真实链路：发送端 percent-encode 进 header，接收端取原始字节
    /// 再 decode，中文文件名必须原样落到对端。
    #[test]
    fn chinese_filename_survives_the_header_roundtrip() {
        let original = "年度报告 2026（终稿）.docx";
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-l78z-filename",
            HeaderValue::from_str(&percent_encode(original)).unwrap(),
        );

        let raw = header_raw(&headers, "x-l78z-filename").expect("header 应存在");
        assert_eq!(sanitize_filename(&percent_decode(&raw)), original);
    }

    /// 旧版对端可能没转义、直接把 UTF-8 塞进 header（落在 obs-text 区间）。
    /// 旧逻辑会因 `to_str()` 失败而丢成 file.bin，新逻辑至少名字还在。
    #[test]
    fn unencoded_utf8_filename_is_not_discarded() {
        let original = "未转义.png";
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-l78z-filename",
            HeaderValue::from_bytes(original.as_bytes()).unwrap(),
        );

        let raw = header_raw(&headers, "x-l78z-filename").expect("header 应存在");
        assert_eq!(sanitize_filename(&percent_decode(&raw)), original);
    }

    #[test]
    fn pairing_json_roundtrip() {
        let info = ConnectInfo {
            name: "pc".into(),
            ip: "192.168.1.5".into(),
            port: 8787,
            token: "abcd".into(),
            ips: vec!["172.24.112.1".into(), "192.168.1.5".into()],
        };
        let s = make_pairing_payload(info.clone()).unwrap();
        let parsed = parse_connect_info(s).unwrap();
        assert_eq!(parsed.ip, info.ip);
        assert_eq!(parsed.token, info.token);
        assert_eq!(parsed.port, 8787);
        assert_eq!(parsed.ips, info.ips);
    }

    /// 旧版二维码（没有 ips 字段）必须仍能解析。
    #[test]
    fn pairing_payload_without_ips_still_parses() {
        let legacy = r#"{"name":"pc","ip":"192.168.1.5","port":8787,"token":"abcd"}"#;
        let parsed = parse_connect_info(legacy.to_string()).unwrap();
        assert_eq!(parsed.ip, "192.168.1.5");
        assert!(parsed.ips.is_empty());
    }

    /// 带 ips 备选地址的真实配对载荷，仍能在 UI 实际使用的 260px 下被识别。
    ///
    /// 二维码内容变大会压缩每个模块的像素，扫不出来是本次改动的连带风险，
    /// 这个测试用真实长度的 name/token/ips 把它钉死。
    #[test]
    fn pairing_qr_roundtrip_at_ui_size() {
        let info = ConnectInfo {
            name: "DESKTOP-EXAMPLE".into(),
            ip: "192.168.0.101".into(),
            port: 8787,
            token: "0123456789abcdef0123456789abcdef".into(),
            ips: vec![
                "172.24.112.1".into(),
                "10.0.0.5".into(),
                "192.168.1.100".into(),
            ],
        };
        let payload = make_pairing_payload(info).unwrap();
        let png = crate::api::qr::generate_qr_png(payload.clone(), 260).unwrap();
        let img = image::load_from_memory(&png).unwrap().into_rgba8();
        let codes =
            crate::api::qr::decode_image(img.clone().into_raw(), img.width(), img.height())
                .unwrap();
        assert!(
            !codes.is_empty(),
            "二维码识别失败（payload {} 字节）",
            payload.len()
        );
        let parsed = parse_connect_info(codes[0].payload.clone()).unwrap();
        assert_eq!(parsed.ip, "192.168.0.101");
        assert_eq!(parsed.token, "0123456789abcdef0123456789abcdef");
        assert_eq!(parsed.ips.len(), 3);
        println!(
            "payload = {} bytes, QR = {}x{}",
            payload.len(),
            img.width(),
            img.height()
        );
    }

    /// 主地址排第一、虚拟网卡地址排在后面，且不重复。
    #[test]
    fn candidate_ips_prefers_primary_and_dedups() {
        let info = ConnectInfo {
            name: "pc".into(),
            ip: "172.24.112.1".into(),
            port: 8787,
            token: "t".into(),
            ips: vec!["172.24.112.1".into(), "192.168.0.101".into(), "".into()],
        };
        assert_eq!(
            candidate_ips(&info),
            vec![
                "172.24.112.1".to_string(),
                "192.168.0.101".to_string()
            ]
        );
    }

    #[test]
    fn parse_rejects_non_pairing() {
        assert!(parse_connect_info("hello world".into()).is_none());
    }

    #[tokio::test]
    async fn server_text_roundtrip() {
        let _guard = server_lock();
        let dir = std::env::temp_dir().join(format!("l78z-test-{}", std::process::id()));
        let info = server_start(0, dir.to_string_lossy().into(), "tester".into()).unwrap();
        let mut rx = events_tx().subscribe();
        client_send_text(info.clone(), "你好".into(), "manual".into(), "peer".into())
            .await
            .unwrap();
        loop {
            match rx.recv().await.unwrap() {
                TransferEvent::TextReceived { text, from, .. } => {
                    assert_eq!(text, "你好");
                    assert_eq!(from, "peer");
                    break;
                }
                TransferEvent::ServerStarted { .. } | TransferEvent::ServerStopped => continue,
                other => panic!("unexpected event: {other:?}"),
            }
        }
        server_stop().unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 反向注册：扫码方把自己的 ConnectInfo 交给对端后，对端才知道怎么发回来。
    ///
    /// 这是"只有扫码的那台能发、被扫的那台发不了"的直接修法。
    #[tokio::test]
    async fn hello_registers_peer_on_the_other_side() {
        let _guard = server_lock();
        let dir = std::env::temp_dir().join(format!("l78z-hello-{}", std::process::id()));
        // 对端（被扫的那一方）的服务
        let peer_info = server_start(0, dir.to_string_lossy().into(), "receiver".into()).unwrap();
        let mut rx = events_tx().subscribe();

        // 本机（扫码的那一方）的信息，要注册给对端
        let self_info = ConnectInfo {
            name: "sender".into(),
            ip: "192.168.0.101".into(),
            port: 9000,
            token: "self-token".into(),
            ips: vec![],
        };

        client_hello(peer_info, self_info).await.unwrap();

        loop {
            match rx.recv().await.unwrap() {
                TransferEvent::PeerRegistered { info } => {
                    assert_eq!(info.name, "sender");
                    assert_eq!(info.ip, "192.168.0.101");
                    assert_eq!(info.port, 9000);
                    break;
                }
                TransferEvent::ServerStarted { .. } | TransferEvent::ServerStopped => continue,
                other => panic!("unexpected event: {other:?}"),
            }
        }
        server_stop().unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 没拿到对方 token 就无法注册（服务端返回 403），
    /// 否则任何人都能把自己的地址塞进别人的配对表。
    ///
    /// 注意 client_hello 的第一个参数是对端的信息、其 token 就是"我扫过你的码"
    /// 的凭证，所以要伪造必须改的是它，而不是 self_info。
    #[tokio::test]
    async fn hello_rejects_bad_token() {
        let _guard = server_lock();
        let dir = std::env::temp_dir().join(format!("l78z-hello-bad-{}", std::process::id()));
        let peer_info = server_start(0, dir.to_string_lossy().into(), "receiver".into()).unwrap();
        let self_info = ConnectInfo {
            name: "sender".into(),
            ip: "192.168.0.101".into(),
            port: 9000,
            token: "self-token".into(),
            ips: vec![],
        };
        let forged = ConnectInfo {
            token: "wrong".into(),
            ..peer_info
        };
        let err = client_hello(forged, self_info).await.unwrap_err();
        assert!(err.to_string().contains("HTTP 403"), "实际错误: {err}");
        server_stop().unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }
}
