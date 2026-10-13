//! LocalSend 官方协议兼容层。
//!
//! 与 l78z 自有协议在同一进程共存，两套 server 各走各的：
//!
//! ```text
//! l78z 自有      HTTP + token             axum，见 api::transfer
//! LocalSend 兼容 HTTPS + 双向证书          vendored core，见本模块
//!                /api/localsend/v2/*
//!                UDP 多播 224.0.0.167
//! ```
//!
//! **端口**：53317 只是 LocalSend 的默认值，不是协议硬要求——多播广播的是
//! **实际监听的端口**，所以配置端口被占用时换随机端口照样能互通。降级顺序
//! 是「配置端口 → 随机端口」；多播 socket 绑不上则由 core 自动降级成
//! 无多播模式（仍可通过主动探测发现对端），原因通过 [`LsEvent::Started`]
//! 带给界面，不闷在日志里。

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

use rand::Rng;
use serde::{Deserialize, Serialize};
use tokio::sync::{broadcast, mpsc, oneshot, RwLock};
use tokio::task::JoinHandle;

use crate::api::transfer::{self, sanitize_filename, unique_path};
use crate::frb_generated::StreamSink;
use localsend::crypto::{cert, hash};
use localsend::discovery::{
    DeviceChannel, DeviceIdentity, DiscoveredDevice, DiscoveryConfig, DiscoveryEvent,
    DiscoveryHandle, HttpChannel, StatefulDevice, DEFAULT_DISCOVERY_TIMEOUT,
};
use localsend::http::client::LsHttpClientV2;
use localsend::http::dto_v2::{PrepareUploadRequestDtoV2, RegisterDtoV2};
use localsend::http::server::common::save::FileUploadTarget;
use localsend::http::server::v2::{PrepareUploadDecisionV2, ServerEventV2};
use localsend::http::server::web::WebConfig;
use localsend::http::server::{start_with_port, ServerConfigV2, TlsConfig};
use localsend::http::state::ClientInfo;
use localsend::model::discovery::{DeviceType, ProtocolType, PROTOCOL_VERSION_V2};
use localsend::model::transfer::{FileContent, FileDto};
use localsend::multicast::{
    DEFAULT_MULTICAST_GROUP, DEFAULT_MULTICAST_GROUP_V6, DEFAULT_PORT as MULTICAST_PORT,
    MulticastDevice,
};
use localsend::util::interface::InterfaceFilter;

/// 周期 announce 的间隔。
///
/// core 自己不做周期 announce：靠「我 announce 一次、之后听对方的」。那
/// 依赖一次 burst 就送达。多发一轮成本只有几秒的 UDP 流量，换来丢包、
/// 对方网络抖动后的自愈，值得。
const ANNOUNCE_INTERVAL: Duration = Duration::from_secs(30);

/// 首次 announce 前的等待。
///
/// server 端口与 discovery 都已就绪，但注册进来的请求要能立刻得到响应，
/// 否则对端收到 announce 就回 register，会撞上我们这边还没跑完的初始化。
const FIRST_ANNOUNCE_DELAY: Duration = Duration::from_millis(300);

/// 兼容层事件，推给 Dart 记录区。
#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum LsEvent {
    /// 已启动。
    Started {
        /// 实际监听的 HTTP 端口（可能与配置不同，已被占用而降级）。
        port: u16,
        /// 多播 socket 是否绑上。绑不上时只能靠主动探测发现对端。
        multicast_ok: bool,
        /// 多播绑不上的原因，直接展示给用户比写进代码注释里更省事。
        multicast_error: Option<String>,
    },
    /// 已停止。
    Stopped,
    /// 发现了一台设备。
    Discovered {
        alias: String,
        version: String,
        ip: String,
        port: u16,
        https: bool,
        device_model: Option<String>,
    },
    /// 对端向本机注册（收到 register 请求）。
    Registered { alias: String, ip: String },
    /// 对端请求推送文件。
    Incoming {
        alias: String,
        ip: String,
        files: usize,
        total_bytes: u64,
    },
    /// 一个文件接收完成。
    Received { name: String, path: String },
    /// 单个文件接收失败。
    ReceiveFailed { name: String, error: String },
    /// 接收会话结束。
    SessionEnd {
        received: usize,
        failed: usize,
        reason: String,
    },
    /// 出错或降级提示。
    Error { message: String },
}

/// 一台可连接的 LocalSend 设备。
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct LsDevice {
    pub alias: String,
    pub version: String,
    pub device_model: Option<String>,
    pub ip: String,
    pub port: u16,
    pub https: bool,
    /// 对端证书的 SHA-256 指纹（大写 hex）。
    ///
    /// 不是秘密——它本来就在多播里广播。发送文件时用它校验证书，这是
    /// LocalSend 唯一能证明「对方确实是它自称的那台设备」的依据。
    pub fingerprint: String,
}

/// 兼容层当前状态，供设置页显示。
#[derive(Clone, Debug, Serialize)]
pub struct LsStatus {
    pub running: bool,
    pub port: u16,
    pub multicast_ok: bool,
    pub multicast_error: Option<String>,
    pub fingerprint: String,
}

/// 证书身份持久化在文档目录。
///
/// **指纹必须稳定**：对端靠它合并同一设备的多个通道，每次启动换一张证书
/// 会被当成一台全新的设备，对方列表里就会出现同名的好几条。
#[derive(Debug, Clone, Serialize, Deserialize)]
struct StoredIdentity {
    cert_pem: String,
    private_key_pem: String,
    fingerprint: String,
}

/// 运行中的兼容层句柄。
struct LsHandle {
    stop_tx: oneshot::Sender<()>,
    discovery_stop_tx: oneshot::Sender<()>,
    tasks: Vec<JoinHandle<()>>,
    port: u16,
    fingerprint: String,
}

/// 单个接收会话的计数。
///
/// 不记 file_id → 文件名的映射：落盘路径在 `handle_file_upload` 里当场
/// 就定下来了，界面要的也只是「收成几个、失败几个」。
struct SessionState {
    received: usize,
    failed: usize,
}

/// 本机在兼容层里的身份。
///
/// 发送文件同样要出示客户端证书——对端开的是 mTLS，没证书连都连不上。
/// 把身份、别名和端口一起留着，免得发送时再去读一遍配置。
#[derive(Clone)]
struct LsSelf {
    identity: StoredIdentity,
    alias: String,
    port: u16,
}

fn self_cell() -> &'static Mutex<Option<LsSelf>> {
    static CELL: OnceLock<Mutex<Option<LsSelf>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(None))
}

fn handle_cell() -> &'static Mutex<Option<LsHandle>> {
    static CELL: OnceLock<Mutex<Option<LsHandle>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(None))
}

/// discovery 句柄用 tokio 锁：`announce()` 一跑就是好几秒，跨 await 持有
/// `std::sync` 的 guard 会让任务不再是 `Send`，直接编译不过。
fn discovery_cell() -> &'static RwLock<Option<DiscoveryHandle>> {
    static CELL: OnceLock<RwLock<Option<DiscoveryHandle>>> = OnceLock::new();
    CELL.get_or_init(|| RwLock::new(None))
}

fn session_cell() -> &'static Mutex<Option<SessionState>> {
    static CELL: OnceLock<Mutex<Option<SessionState>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(None))
}

/// 已发现设备的缓存。
///
/// 不让界面直接去读 discovery：那样要么阻塞 UI 等锁，要么得处理「正在
/// announce 拿不到」的竞态。事件一来这里就刷新，界面读到的永远是快照。
fn devices_cache() -> &'static Mutex<Vec<LsDevice>> {
    static CELL: OnceLock<Mutex<Vec<LsDevice>>> = OnceLock::new();
    CELL.get_or_init(|| Mutex::new(Vec::new()))
}

fn events_tx() -> &'static broadcast::Sender<LsEvent> {
    static TX: OnceLock<broadcast::Sender<LsEvent>> = OnceLock::new();
    TX.get_or_init(|| broadcast::channel(64).0)
}

fn emit(ev: LsEvent) {
    let _ = events_tx().send(ev);
}

/// 订阅兼容层事件流。
pub fn ls_events(sink: StreamSink<LsEvent>) {
    let mut rx = events_tx().subscribe();
    transfer::runtime().spawn(async move {
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

/// 读取已发现的设备（快照，不阻塞）。
pub fn ls_devices() -> Vec<LsDevice> {
    devices_cache().lock().unwrap().clone()
}

/// 当前状态。
pub fn ls_status() -> LsStatus {
    let handle = handle_cell().lock().unwrap();
    let (port, fingerprint) = match handle.as_ref() {
        Some(h) => (h.port, h.fingerprint.clone()),
        None => (0, String::new()),
    };
    let (multicast_ok, multicast_error) = match discovery_cell().try_read() {
        Ok(guard) => match guard.as_ref() {
            Some(d) => match d.multicast_error() {
                None => (true, None),
                Some(e) => (false, Some(format!("{e:#}"))),
            },
            None => (false, None),
        },
        // 正被 announce 读锁占着：不阻塞调用方，按「已启动但未知多播状态」返回。
        Err(_) => (false, None),
    };
    let running = handle.is_some();
    drop(handle);

    LsStatus {
        running,
        port,
        multicast_ok: running && multicast_ok,
        multicast_error: if running { multicast_error } else { None },
        fingerprint,
    }
}

/// 加载或生成设备身份。
///
/// 证书是 LocalSend 强制 HTTPS 的前提，指纹则是对端识别「还是同一台设备」
/// 的唯一依据，所以两样都必须落盘复用。
fn load_or_create_identity(save_dir: &str) -> anyhow::Result<StoredIdentity> {
    let path = Path::new(save_dir).join("ls-identity.json");
    if let Ok(text) = std::fs::read_to_string(&path) {
        if let Ok(id) = serde_json::from_str::<StoredIdentity>(&text) {
            if !id.cert_pem.is_empty()
                && !id.private_key_pem.is_empty()
                && !id.fingerprint.is_empty()
            {
                return Ok(id);
            }
        }
    }

    let c = cert::generate_self_signed()?;
    let id = StoredIdentity {
        cert_pem: c.certificate_pem,
        private_key_pem: c.private_key_pem,
        fingerprint: c.fingerprint,
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    // 写盘失败不致命：本次照样能用，只是下次启动会重新生成一张证书。
    if let Err(e) = std::fs::write(&path, serde_json::to_string_pretty(&id)?) {
        emit(LsEvent::Error {
            message: format!("设备身份未能保存（{e}），本次为临时证书"),
        });
    }
    Ok(id)
}

/// 选一个能绑上的端口。
///
/// 先试配置值，被占用就退回 0（由 OS 分配）。因为多播广播的是实际端口，
/// 换端口并不影响与官方 LocalSend 的互通，只是设置页显示的数字会变。
///
/// 这里先探测再交给 core：core 内部对 bind 失败是直接返回错误的，没有降级
/// 逻辑，不预先选好端口就会整个启动失败。
fn pick_port(hint: u16) -> u16 {
    if hint == 0 {
        return 0;
    }
    match std::net::TcpListener::bind(("0.0.0.0", hint)) {
        Ok(_) => hint,
        Err(_) => 0,
    }
}

fn device_type() -> DeviceType {
    if cfg!(target_os = "android") || cfg!(target_os = "ios") {
        DeviceType::Mobile
    } else {
        DeviceType::Desktop
    }
}

fn device_model() -> Option<String> {
    if cfg!(target_os = "android") {
        Some("Android".to_string())
    } else if cfg!(target_os = "windows") {
        Some("Windows".to_string())
    } else if cfg!(target_os = "macos") {
        Some("macOS".to_string())
    } else if cfg!(target_os = "linux") {
        Some("Linux".to_string())
    } else {
        None
    }
}

/// 把 discovery 里的设备转成对外快照（带可连接的地址）。
fn to_ls_device(d: &StatefulDevice) -> Option<LsDevice> {
    let http = d.device.channel.http()?;
    Some(LsDevice {
        alias: d.device.alias.clone(),
        version: d.device.version.clone(),
        device_model: d.device.device_model.clone(),
        ip: http.host.clone(),
        port: http.port,
        https: matches!(http.protocol, ProtocolType::Https),
        fingerprint: d.device.fingerprint.clone(),
    })
}

fn refresh_devices_cache(snapshot: &[StatefulDevice]) {
    let list: Vec<LsDevice> = snapshot.iter().filter_map(to_ls_device).collect();
    *devices_cache().lock().unwrap() = list;
}

/// 启动 LocalSend 兼容层。
pub fn ls_start(
    save_dir: String,
    device_name: String,
    port_hint: u16,
    pin: Option<String>,
    verify_checksums: bool,
) -> anyhow::Result<LsStatus> {
    ls_stop().ok();

    let identity = load_or_create_identity(&save_dir)?;
    let save_dir_path = PathBuf::from(&save_dir);
    let port = pick_port(port_hint);

    // server 侧事件通道
    let (ev_tx, ev_rx) = mpsc::channel::<ServerEventV2>(64);
    let (stop_tx, stop_rx) = oneshot::channel::<()>();

    let tls = TlsConfig {
        cert: identity.cert_pem.clone(),
        private_key: identity.private_key_pem.clone(),
    };

    let client_info = ClientInfo {
        alias: device_name.clone(),
        version: PROTOCOL_VERSION_V2.to_string(),
        device_model: device_model(),
        device_type: Some(device_type()),
        // 官方用 token 合并同一设备的多条通道；这里用证书指纹，天然唯一。
        token: identity.fingerprint.clone(),
    };

    let bound_port = transfer::runtime()
        .block_on(start_with_port(
            port,
            Some(tls),
            client_info,
            None,
            Some(ServerConfigV2 {
                pin,
                verify_checksums,
                event_tx: ev_tx,
            }),
            WebConfig::default(),
            stop_rx,
        ))?
        .port();

    // discovery 必须在 server 之后起：多播广播的正是 server 实际绑到的端口。
    let (ds_ev_tx, ds_ev_rx) = mpsc::channel::<DiscoveryEvent>(64);
    let (ds_stop_tx, ds_stop_rx) = oneshot::channel::<()>();
    let discovery = transfer::runtime().block_on(localsend::discovery::start(
        DiscoveryConfig {
            group: DEFAULT_MULTICAST_GROUP,
            group_v6: Some(DEFAULT_MULTICAST_GROUP_V6),
            port: MULTICAST_PORT,
            interface_filter: InterfaceFilter::default(),
            device: MulticastDevice {
                alias: device_name.clone(),
                version: PROTOCOL_VERSION_V2.to_string(),
                device_model: device_model(),
                device_type: Some(device_type()),
                fingerprint: identity.fingerprint.clone(),
                port: bound_port,
                protocol: ProtocolType::Https,
                download: true,
            },
            identity: DeviceIdentity {
                cert_pem: identity.cert_pem.clone(),
                private_key_pem: identity.private_key_pem.clone(),
            },
            timeout: DEFAULT_DISCOVERY_TIMEOUT,
            event_tx: Some(ds_ev_tx),
        },
        ds_stop_rx,
    ));

    let multicast_error = discovery.multicast_error().map(|e| format!("{e:#}"));
    let multicast_ok = multicast_error.is_none();

    // 先把句柄放进去再 spawn announce：那些任务一醒来就要读它，
    // 靠 sleep 的 300ms 去赌时序没必要。
    *discovery_cell().blocking_write() = Some(discovery);
    devices_cache().lock().unwrap().clear();
    *session_cell().lock().unwrap() = None;
    // 发送方同样要出示客户端证书（对端开的是 mTLS），所以身份不只服务端用得着。
    *self_cell().lock().unwrap() = Some(LsSelf {
        identity: identity.clone(),
        alias: device_name.clone(),
        port: bound_port,
    });

    let tasks = vec![
        transfer::runtime().spawn(server_events(ev_rx, save_dir_path)),
        transfer::runtime().spawn(discovery_events(ds_ev_rx)),
        transfer::runtime().spawn(periodic_announce()),
        transfer::runtime().spawn(first_announce()),
    ];

    *handle_cell().lock().unwrap() = Some(LsHandle {
        stop_tx,
        discovery_stop_tx: ds_stop_tx,
        tasks,
        port: bound_port,
        fingerprint: identity.fingerprint.clone(),
    });

    emit(LsEvent::Started {
        port: bound_port,
        multicast_ok,
        multicast_error: multicast_error.clone(),
    });

    Ok(LsStatus {
        running: true,
        port: bound_port,
        multicast_ok,
        multicast_error,
        fingerprint: identity.fingerprint,
    })
}

/// 停止兼容层。
pub fn ls_stop() -> anyhow::Result<()> {
    if let Some(h) = handle_cell().lock().unwrap().take() {
        let _ = h.stop_tx.send(());
        let _ = h.discovery_stop_tx.send(());
        for t in h.tasks {
            t.abort();
        }
    }
    // 这是同步函数，拿 tokio 锁不能阻塞等：try_write 拿不到就说明此刻正有
    // announce 持着读锁，那也没关系——任务已经被 abort，下次启动会覆盖。
    if let Ok(mut g) = discovery_cell().try_write() {
        g.take();
    }
    *session_cell().lock().unwrap() = None;
    devices_cache().lock().unwrap().clear();
    *self_cell().lock().unwrap() = None;
    emit(LsEvent::Stopped);
    Ok(())
}

/// 向一台已发现的 LocalSend 设备发送文件。
///
/// 走完整的 v2 流程：register（换回对端公钥）→ prepare-upload（换回
/// session 与每文件的 token）→ upload（流式传内容）。
///
/// `https` 为假时 `fingerprint` 用不上——HTTP 本来就没有证书可校验。
pub async fn ls_send_file(
    ip: String,
    port: u16,
    https: bool,
    fingerprint: String,
    file_path: String,
) -> anyhow::Result<String> {
    // 先查兼容层状态再碰文件：状态是根本前提。没开兼容层时，哪怕路径也
    // 有问题，也该先告诉用户去哪儿把它打开，而不是甩一句「读不到文件」。
    let me = self_cell()
        .lock()
        .unwrap()
        .clone()
        .ok_or_else(|| anyhow::anyhow!("兼容层未启动，请先在设置里启用 LocalSend 兼容"))?;

    let path = PathBuf::from(&file_path);
    let meta = tokio::fs::metadata(&path)
        .await
        .map_err(|e| anyhow::anyhow!("读不到文件 {file_path}：{e}"))?;
    let file_name = path
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| "file".to_string());
    let size = meta.len();

    let protocol = if https {
        ProtocolType::Https
    } else {
        ProtocolType::Http
    };
    let client = LsHttpClientV2::try_new(
        &me.identity.private_key_pem,
        &me.identity.cert_pem,
        if https { Some(fingerprint) } else { None },
        Some(Duration::from_secs(30)),
    )
    .map_err(|e| anyhow::anyhow!("建不了 HTTPS 连接：{e}"))?;

    let cancel = tokio_util::sync::CancellationToken::new();
    let info = RegisterDtoV2 {
        alias: me.alias.clone(),
        version: PROTOCOL_VERSION_V2.to_string(),
        device_model: device_model(),
        device_type: Some(device_type()),
        fingerprint: me.identity.fingerprint.clone(),
        port: me.port,
        protocol: ProtocolType::Https,
        download: true,
    };

    let registered = client
        .register(protocol, &ip, port, info.clone())
        .await
        .map_err(|e| anyhow::anyhow!("向对端注册失败：{e}"))?;
    let public_key = registered.public_key;

    // 校验和必须给：对端收完会比对，不给就等于「传完了但没人知道对不对」。
    let sha256 = hash::sha256_file_content(FileContent::Path(path.clone()), &cancel, |_| {})
        .await
        .map_err(|e| anyhow::anyhow!("算校验和失败：{e:?}"))?;

    let file_id = new_file_id();
    let mut files = HashMap::new();
    files.insert(
        file_id.clone(),
        FileDto {
            id: file_id.clone(),
            file_name: file_name.clone(),
            size,
            file_type: guess_file_type(&file_name),
            sha256: Some(sha256),
            preview: None,
            metadata: None,
        },
    );

    let prepared = client
        .prepare_upload(
            protocol,
            &ip,
            port,
            public_key.clone(),
            PrepareUploadRequestDtoV2 { info, files },
            None,
            cancel.clone(),
        )
        .await
        .map_err(|e| anyhow::anyhow!("对端拒绝或不可达：{e}"))?;

    let response = prepared
        .response
        .ok_or_else(|| anyhow::anyhow!("对端表示无需传输（可能取消了勾选）"))?;
    let token = response
        .files
        .get(&file_id)
        .ok_or_else(|| anyhow::anyhow!("对端没回这个文件的上传凭证"))?
        .clone();

    let file = tokio::fs::File::open(&path).await?;
    let body = localsend::reqwest::Body::wrap_stream(tokio_util::io::ReaderStream::new(file));
    client
        .upload(
            protocol,
            &ip,
            port,
            public_key,
            &response.session_id,
            &file_id,
            &token,
            body,
            cancel,
        )
        .await
        .map_err(|e| anyhow::anyhow!("传输失败：{e}"))?;

    Ok(file_name)
}

/// 生成文件 id。LocalSend 只要求它在会话内唯一，随机 hex 足够。
fn new_file_id() -> String {
    let mut rng = rand::rng();
    format!("{:016x}{:016x}", rng.random::<u64>(), rng.random::<u64>())
}

/// 按扩展名给一个 MIME 类型。
///
/// 对端拿它挑图标，猜不出来就给通用的——不影响能不能传，只是对方看到的
/// 是「未知文件」而不是「图片」。
fn guess_file_type(name: &str) -> String {
    let lower = name.to_ascii_lowercase();
    let ext = lower.rsplit_once('.').map(|(_, e)| e).unwrap_or("");
    match ext {
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "bmp" | "heic" => "image/*".to_string(),
        "mp4" | "mkv" | "avi" | "mov" | "webm" => "video/*".to_string(),
        "mp3" | "wav" | "flac" | "aac" | "ogg" => "audio/*".to_string(),
        "pdf" => "application/pdf".to_string(),
        "txt" | "md" | "log" | "csv" => "text/plain".to_string(),
        "zip" | "rar" | "7z" | "tar" | "gz" => "application/zip".to_string(),
        _ => "application/octet-stream".to_string(),
    }
}

async fn first_announce() {
    tokio::time::sleep(FIRST_ANNOUNCE_DELAY).await;
    announce_now().await;
}

async fn periodic_announce() {
    loop {
        tokio::time::sleep(ANNOUNCE_INTERVAL).await;
        announce_now().await;
    }
}

async fn announce_now() {
    let guard = discovery_cell().read().await;
    if let Some(d) = guard.as_ref() {
        d.announce().await;
    }
}

/// 处理 core 发来的 server 事件。
async fn server_events(mut rx: mpsc::Receiver<ServerEventV2>, save_dir: PathBuf) {
    while let Some(ev) = rx.recv().await {
        match ev {
            ServerEventV2::Register { ip, info } => {
                let host = ip.to_string();
                emit(LsEvent::Registered {
                    alias: info.alias.clone(),
                    ip: host.clone(),
                });

                // 对端是听到我们的 announce 才来注册的，它自己未必也在我们
                // 的 discovery 列表里——回灌一次，否则设备列表是单向的。
                let device = DiscoveredDevice {
                    alias: info.alias.clone(),
                    version: info.version.clone(),
                    device_model: info.device_model.clone(),
                    device_type: info.device_type.clone(),
                    fingerprint: info.fingerprint.clone(),
                    channel: DeviceChannel::Http(HttpChannel {
                        host: host.clone(),
                        port: info.port,
                        protocol: info.protocol,
                    }),
                    download: info.download,
                };
                let snapshot = {
                    let guard = discovery_cell().read().await;
                    match guard.as_ref() {
                        Some(d) => {
                            d.add_device(device).await;
                            d.devices()
                        }
                        None => Vec::new(),
                    }
                };
                refresh_devices_cache(&snapshot);
            }

            // session_id 只用于 core 内部配对，界面上要展示的是收了几个
            // 文件，所以交给 `..` 忽略。
            ServerEventV2::PrepareUpload {
                ip,
                info,
                files,
                decision_tx,
                ..
            } => {
                let total: u64 = files.values().map(|f| f.size).sum();
                *session_cell().lock().unwrap() = Some(SessionState {
                    received: 0,
                    failed: 0,
                });
                emit(LsEvent::Incoming {
                    alias: info.alias.clone(),
                    ip: ip.to_string(),
                    files: files.len(),
                    total_bytes: total,
                });
                // 全部接受。core 侧的筛选接口是
                // `PrepareUploadDecisionV2::Accept(HashSet<_>)`；
                // 传空集合表示「什么都不用传」，那不是这里要的。
                let ids: HashSet<String> = files.keys().cloned().collect();
                let _ = decision_tx.send(PrepareUploadDecisionV2::Accept(ids));
            }

            ServerEventV2::FileUpload {
                file_id, file, target_tx, ..
            } => {
                handle_file_upload(&save_dir, file_id, file, target_tx);
            }

            ServerEventV2::SessionEnd { reason, .. } => {
                let (received, failed) = session_cell()
                    .lock()
                    .unwrap()
                    .take()
                    .map(|s| (s.received, s.failed))
                    .unwrap_or((0, 0));
                emit(LsEvent::SessionEnd {
                    received,
                    failed,
                    reason: format!("{reason:?}"),
                });
            }

            ServerEventV2::ListenerFailed { error } => {
                emit(LsEvent::Error {
                    message: format!("LocalSend 服务停止监听：{error}"),
                });
            }

            // 其余变体（会话中途放弃等）对界面没有可展示的信息。
            _ => {}
        }
    }
}

/// 决定一个上传文件往哪儿写。
///
/// 用 `FileUploadTarget::Path` 而非 `Stream`：写盘、校验 SHA-256、回填
/// 时间戳都由 core 做完，我们只收一个结果。自己接流式写盘等于把这些
/// 再抄一遍，还要自己处理校验失败的归因。
fn handle_file_upload(
    save_dir: &Path,
    file_id: String,
    file: FileDto,
    target_tx: oneshot::Sender<FileUploadTarget>,
) {
    let _ = file_id;
    let name = sanitize_filename(&file.file_name);
    let path = unique_path(save_dir, &name);
    let shown_name = path
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| name.clone());

    let (result_tx, result_rx) = oneshot::channel::<Result<(), String>>();
    if target_tx
        .send(FileUploadTarget::Path {
            path: path.clone(),
            result_tx,
            progress_tx: None,
        })
        .is_err()
    {
        // 对端已经走了，没什么可报的。
        return;
    }

    transfer::runtime().spawn(async move {
        let (ok, error) = match result_rx.await {
            Ok(Ok(())) => (true, String::new()),
            // core 在写盘失败或 SHA-256 对不上时给的是这句。
            Ok(Err(e)) => (false, e),
            Err(_) => (false, "对端中断了传输".to_string()),
        };

        if let Some(s) = session_cell().lock().unwrap().as_mut() {
            if ok {
                s.received += 1;
            } else {
                s.failed += 1;
            }
        }

        if ok {
            emit(LsEvent::Received {
                name: shown_name,
                path: path.to_string_lossy().into_owned(),
            });
        } else {
            emit(LsEvent::ReceiveFailed {
                name: shown_name,
                error,
            });
        }
    });
}

/// 处理 discovery 事件。
async fn discovery_events(mut rx: mpsc::Receiver<DiscoveryEvent>) {
    while let Some(ev) = rx.recv().await {
        match ev {
            DiscoveryEvent::Discovered { device } | DiscoveryEvent::Updated { device } => {
                let snapshot = {
                    let guard = discovery_cell().read().await;
                    guard.as_ref().map(|d| d.devices()).unwrap_or_default()
                };
                refresh_devices_cache(&snapshot);

                // 先把要展示的字段搬出来，再和 channel 的借用共存——
                // `device.channel.http()` 借着 device，直接在里面 move
                // device.alias 会让借用检查变绕。
                if let Some(http) = device.channel.http() {
                    let (host, port, protocol) = (http.host.clone(), http.port, http.protocol);
                    let (alias, version, model) = (
                        device.alias.clone(),
                        device.version.clone(),
                        device.device_model.clone(),
                    );
                    emit(LsEvent::Discovered {
                        alias,
                        version,
                        ip: host,
                        port,
                        https: matches!(protocol, ProtocolType::Https),
                        device_model: model,
                    });
                }
            }
            DiscoveryEvent::MulticastFailed => {
                emit(LsEvent::Error {
                    message: "多播通道失效，已降级为主动探测".to_string(),
                });
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use std::sync::Arc;

    fn temp_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("l78z-ls-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn stateful(host: &str, port: u16) -> StatefulDevice {
        StatefulDevice {
            device: DiscoveredDevice {
                alias: "手机".into(),
                version: PROTOCOL_VERSION_V2.into(),
                device_model: Some("Android".into()),
                device_type: Some(DeviceType::Mobile),
                fingerprint: "ABC123".into(),
                channel: DeviceChannel::Http(HttpChannel {
                    host: host.into(),
                    port,
                    protocol: ProtocolType::Https,
                }),
                download: true,
            },
            channels: HashMap::new(),
            logs: Vec::new(),
        }
    }

    #[test]
    fn identity_is_created_once_and_stays_stable() {
        let dir = temp_dir("identity");

        let a = load_or_create_identity(&dir.to_string_lossy()).unwrap();
        let b = load_or_create_identity(&dir.to_string_lossy()).unwrap();

        // 指纹一变，对端就当成一台新设备，列表里会堆出同名的几条。
        assert_eq!(a.fingerprint, b.fingerprint);
        assert_eq!(a.cert_pem, b.cert_pem);
        assert!(!a.fingerprint.is_empty());
        assert!(a.cert_pem.contains("BEGIN CERTIFICATE"));
        assert!(a.private_key_pem.contains("PRIVATE KEY"));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn corrupt_identity_file_is_regenerated() {
        let dir = temp_dir("identity-corrupt");
        std::fs::write(dir.join("ls-identity.json"), "{ 这不是 json").unwrap();

        // 坏文件不能让启动直接失败——重发一张证书总好过整个兼容层起不来。
        let id = load_or_create_identity(&dir.to_string_lossy()).unwrap();
        assert!(!id.fingerprint.is_empty());

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn pick_port_degrades_when_the_hint_is_taken() {
        // 占住一个端口，验证降级链：配置端口被占 → 交给 OS 随机分配。
        let taken = std::net::TcpListener::bind(("0.0.0.0", 0)).unwrap();
        let busy = taken.local_addr().unwrap().port();

        assert_eq!(pick_port(busy), 0, "端口被占用时应退回随机端口");
        assert_eq!(pick_port(0), 0, "0 表示交给 OS，不是真实端口");

        drop(taken);
    }

    #[test]
    fn pick_port_keeps_an_idle_hint() {
        let probe = std::net::TcpListener::bind(("0.0.0.0", 0)).unwrap();
        let free = probe.local_addr().unwrap().port();
        drop(probe);

        // 刚释放的端口应当还能用回来；这里的相等才是正常路径。
        assert_eq!(pick_port(free), free);
    }

    #[test]
    fn discovered_device_carries_a_reachable_address() {
        // 转换层只关心一件事：拿不拿得到 ip:port。拿不到就无法连接，
        // 也不该出现在设备列表里占位置。
        let ls = to_ls_device(&stateful("192.168.1.8", 53317)).expect("应能取出地址");
        assert_eq!(ls.alias, "手机");
        assert_eq!(ls.ip, "192.168.1.8");
        assert_eq!(ls.port, 53317);
        assert!(ls.https);
        assert_eq!(ls.device_model.as_deref(), Some("Android"));
    }

    #[test]
    fn device_type_matches_this_platform() {
        // 官方用它选图标：Android / iOS 必须报 Mobile，否则对端显示成电脑。
        let expected = if cfg!(target_os = "android") || cfg!(target_os = "ios") {
            DeviceType::Mobile
        } else {
            DeviceType::Desktop
        };
        assert_eq!(device_type(), expected);
    }

    #[test]
    fn empty_device_cache_is_the_safe_default() {
        // 没启动过兼容层时，界面拿到的是空列表而不是 panic。
        let _ = ls_devices();
    }

    #[test]
    fn file_type_is_guessed_from_the_extension() {
        // 对端拿它挑图标。猜错不影响传输，但猜不出就只剩「未知文件」。
        assert_eq!(guess_file_type("a.png"), "image/*");
        assert_eq!(guess_file_type("录像.MP4"), "video/*");
        assert_eq!(guess_file_type("notes.txt"), "text/plain");
        assert_eq!(guess_file_type("a.b.c.zip"), "application/zip");
        assert_eq!(guess_file_type("没扩展名"), "application/octet-stream");
    }

    /// 会碰全局单例的测试必须串行：`ls_start` 刚建好的身份，可能被另一个
    /// 测试的清理给清掉，而那种失败查起来会非常折磨。
    fn global_lock() -> &'static Mutex<()> {
        static L: OnceLock<Mutex<()>> = OnceLock::new();
        L.get_or_init(|| Mutex::new(()))
    }

    /// 锁被 panic 毒化后仍能拿到，否则一个失败会连累后面所有测试。
    fn lock_globals() -> std::sync::MutexGuard<'static, ()> {
        global_lock().lock().unwrap_or_else(|e| e.into_inner())
    }

    #[test]
    fn sending_without_a_running_layer_fails_with_a_readable_reason() {
        let _guard = lock_globals();
        // 兼容层没起就发不出去，但错误得说人话——只丢一句英文异常给用户，
        // 等于没告诉他该怎么办。
        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();

        rt.block_on(async {
            self_cell().lock().unwrap().take();
            let err = ls_send_file(
                "127.0.0.1".into(),
                53317,
                false,
                String::new(),
                "根本不存在的文件".into(),
            )
            .await
            .unwrap_err();
            assert!(
                err.to_string().contains("兼容层未启动"),
                "错误信息应指向设置页，实际是：{err}"
            );
        });
    }

    /// `ls_start` 的整条链路：证书 → 落盘 → 端口 → server → 多播 → 状态查询。
    ///
    /// 端口传 0 走随机分配，避免和这台机器上真正跑着的服务撞上。
    /// 刻意不断言多播状态：它取决于网络环境，环境问题不该让测试变红。
    #[test]
    fn ls_start_brings_up_the_whole_layer() {
        let _guard = lock_globals();
        let dir = temp_dir("start");

        let status = ls_start(
            dir.to_string_lossy().into_owned(),
            "测试机".into(),
            0,
            None,
            true,
        )
        .expect("兼容层应能启动");

        assert!(status.running);
        assert!(
            status.port > 0,
            "随机端口也该给出实际值，实际是 {}",
            status.port
        );
        assert!(!status.fingerprint.is_empty(), "必须生成证书指纹");

        // 指纹要落盘，否则下次启动就成了「另一台设备」，对方列表里会堆出
        // 同名的重复条目。
        assert!(dir.join("ls-identity.json").exists(), "身份没有写盘");
        let again = load_or_create_identity(&dir.to_string_lossy()).unwrap();
        assert_eq!(again.fingerprint, status.fingerprint, "重启后指纹应保持不变");

        // 运行期间的状态查询不能卡住，也不能报「没在跑」。
        let live = ls_status();
        assert!(live.running, "运行中应报告 running");
        assert_eq!(live.port, status.port);
        let _ = ls_devices(); // 列表此时为空很正常，这里只保证读得到

        ls_stop().unwrap();
        assert!(!ls_status().running, "停止后应报告未运行");

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 一端：server + discovery + 把 register 回灌进 discovery 的循环。
    struct End {
        handle: Arc<DiscoveryHandle>,
        multicast_error: Option<String>,
        _server: localsend::http::server::ServerHandle,
        /// 两个 oneshot 的发送端都必须留住：一旦 drop，对端 receiver 就会
        /// 收到错误并把对应的 server / discovery 停掉。
        _stop: oneshot::Sender<()>,
        _ds_stop: oneshot::Sender<()>,
    }

    impl End {
        async fn spawn(alias: &str) -> Self {
            let identity = cert::generate_self_signed().expect("证书生成失败");
            let (ev_tx, mut ev_rx) = mpsc::channel::<ServerEventV2>(64);
            let (stop_tx, stop_rx) = oneshot::channel::<()>();
            let (ds_stop_tx, ds_stop_rx) = oneshot::channel::<()>();

            let server = start_with_port(
                0,
                Some(TlsConfig {
                    cert: identity.certificate_pem.clone(),
                    private_key: identity.private_key_pem.clone(),
                }),
                ClientInfo {
                    alias: alias.into(),
                    version: PROTOCOL_VERSION_V2.into(),
                    device_model: None,
                    device_type: Some(DeviceType::Desktop),
                    token: identity.fingerprint.clone(),
                },
                None,
                Some(ServerConfigV2 {
                    pin: None,
                    verify_checksums: true,
                    event_tx: ev_tx,
                }),
                WebConfig::default(),
                stop_rx,
            )
            .await
            .expect("server 启动失败");

            let handle = Arc::new(
                localsend::discovery::start(
                    DiscoveryConfig {
                        group: DEFAULT_MULTICAST_GROUP,
                        // 测互通只关心 IPv4 主路径，省掉 IPv6 变量。
                        group_v6: None,
                        port: MULTICAST_PORT,
                        interface_filter: InterfaceFilter::default(),
                        device: MulticastDevice {
                            alias: alias.into(),
                            version: PROTOCOL_VERSION_V2.into(),
                            device_model: None,
                            device_type: Some(DeviceType::Desktop),
                            fingerprint: identity.fingerprint.clone(),
                            port: server.port(),
                            protocol: ProtocolType::Https,
                            download: true,
                        },
                        identity: DeviceIdentity {
                            cert_pem: identity.certificate_pem.clone(),
                            private_key_pem: identity.private_key_pem.clone(),
                        },
                        timeout: DEFAULT_DISCOVERY_TIMEOUT,
                        event_tx: None,
                    },
                    ds_stop_rx,
                )
                .await,
            );

            let multicast_error = handle.multicast_error().map(|e| e.to_string());

            // register 必须回灌：discovery 只认自己听到的 announce，
            // 而「对方 announce → 我 register 回去」这条路径根本不经过 discovery。
            let feed = handle.clone();
            tokio::spawn(async move {
                while let Some(ev) = ev_rx.recv().await {
                    if let ServerEventV2::Register { ip, info } = ev {
                        feed.add_device(DiscoveredDevice {
                            alias: info.alias.clone(),
                            version: info.version.clone(),
                            device_model: info.device_model.clone(),
                            device_type: info.device_type.clone(),
                            fingerprint: info.fingerprint.clone(),
                            channel: DeviceChannel::Http(HttpChannel {
                                host: ip.to_string(),
                                port: info.port,
                                protocol: info.protocol,
                            }),
                            download: info.download,
                        })
                        .await;
                    }
                }
            });

            End {
                handle,
                multicast_error,
                _server: server,
                _stop: stop_tx,
                _ds_stop: ds_stop_tx,
            }
        }
    }

    /// 阶段一的过关标准：两套独立证书身份能否靠多播互相发现。
    ///
    /// 不走 `ls_start`——它是全局单例，一个进程只能跑一份，而互通本来就需要
    /// 两方。这里直接用 core 的 API 拼出甲/乙，验证的是 vendored core 加上
    /// 我们这套配置（自签证书、HTTPS、多播端口）确实能互通。
    ///
    /// 会向局域网发 UDP 多播包，无害但确实存在，所以仅在测试里跑。
    /// 多播被网络禁用时直接跳过：那不是本项目的 bug，不该把测试搞成红的。
    #[test]
    fn two_ends_discover_each_other_over_multicast() {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap();

        rt.block_on(async move {
            let a = End::spawn("甲").await;
            let b = End::spawn("乙").await;

            if a.multicast_error.is_some() || b.multicast_error.is_some() {
                eprintln!(
                    "跳过：本机多播不可用（甲 {} / 乙 {}）",
                    a.multicast_error.as_deref().unwrap_or("-"),
                    b.multicast_error.as_deref().unwrap_or("-"),
                );
                return;
            }

            // announce 是一次 burst，调用本身就要花几秒才返回。
            a.handle.announce().await;
            // 对端听到后发 register，我们再回灌进 discovery。
            tokio::time::sleep(Duration::from_secs(3)).await;

            let aliases = |h: &DiscoveryHandle| -> Vec<String> {
                h.devices().iter().map(|d| d.device.alias.clone()).collect()
            };

            let seen_by_a = aliases(&a.handle);
            let seen_by_b = aliases(&b.handle);
            assert!(
                seen_by_a.contains(&"乙".to_string()),
                "甲没有发现乙，当前列表：{seen_by_a:?}"
            );
            assert!(
                seen_by_b.contains(&"甲".to_string()),
                "乙没有发现甲，当前列表：{seen_by_b:?}"
            );
        });
    }
}
