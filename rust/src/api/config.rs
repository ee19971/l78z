use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::util::net;

/// 本机默认监听端口，与官方 LocalSend 保持一致，便于互发现。
///
/// 只是默认值而非硬性要求：LocalSend 多播广播的是**实际监听的端口**，
/// 所以被占用时换一个端口照样能互通。
const DEFAULT_PORT: u16 = 53317;

/// 应用配置。存在文档目录的 JSON 里，由 Dart 侧传入路径。
///
/// 配置放 Rust 这边而不是 Dart 侧，是因为端口、设备名、PIN 最终都要交给
/// 传输服务使用，存这里省得跨层来回传，也不必为设置页单独引入存储插件。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AppConfig {
    /// 设备名称，出现在对端的设备列表里。
    pub device_name: String,

    /// LocalSend 兼容层的监听端口。
    pub port: u16,

    /// 传输 PIN：非空时，对端必须在查询参数里带上它才能推送文件。
    #[serde(default)]
    pub pin: Option<String>,

    /// 收到文件后是否校验发送方提供的 SHA-256。
    #[serde(default = "default_true")]
    pub verify_checksums: bool,

    /// 是否启用 LocalSend 兼容层。
    ///
    /// 目前恒为 false：兼容层尚未实现，UI 上该开关是禁用态。
    #[serde(default)]
    pub ls_compat_enabled: bool,
}

fn default_true() -> bool {
    true
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            device_name: net::device_name(),
            port: DEFAULT_PORT,
            pin: None,
            verify_checksums: true,
            ls_compat_enabled: false,
        }
    }
}

/// 读取配置。
///
/// 文件不存在时返回默认值（首次启动的正常情况）。文件损坏时不抛错——
/// 抛错会让设置页直接打不开——而是把坏文件改名留档后重建一份默认配置，
/// 这样用户之前填的设备名等至少能在 `.bak` 里找回来。
pub fn load_config(path: String) -> anyhow::Result<AppConfig> {
    let p = Path::new(&path);
    if !p.exists() {
        return Ok(AppConfig::default());
    }

    let text = std::fs::read_to_string(p)?;
    match serde_json::from_str::<AppConfig>(&text) {
        Ok(mut cfg) => {
            sanitize(&mut cfg);
            Ok(cfg)
        }
        Err(e) => {
            let bak = format!("{path}.bak");
            let _ = std::fs::rename(p, &bak);
            let cfg = AppConfig::default();
            let _ = save_config(path, cfg.clone());
            eprintln!("[config] 配置已损坏（{e}），原文件留档为 {bak}");
            Ok(cfg)
        }
    }
}

/// 保存配置。写入过程是「先写临时文件再改名」，中途被杀也不会留下半截 JSON，
/// 否则下次加载会把它当成损坏配置丢弃。
pub fn save_config(path: String, cfg: AppConfig) -> anyhow::Result<AppConfig> {
    let p = Path::new(&path);
    if let Some(dir) = p.parent() {
        std::fs::create_dir_all(dir)?;
    }

    let tmp = format!("{path}.part");
    std::fs::write(&tmp, serde_json::to_string_pretty(&cfg)?)?;
    // Windows 上 rename 到已存在的目标会失败，先删掉旧文件。
    if p.exists() {
        let _ = std::fs::remove_file(p);
    }
    std::fs::rename(&tmp, p)?;

    Ok(cfg)
}

/// 修掉明显不可用的值，避免配置被手改坏后导致监听失败。
fn sanitize(cfg: &mut AppConfig) {
    if cfg.port == 0 {
        cfg.port = DEFAULT_PORT;
    }
    let trimmed = cfg.device_name.trim();
    if trimmed.is_empty() {
        cfg.device_name = net::device_name();
    } else if trimmed != cfg.device_name {
        cfg.device_name = trimmed.to_string();
    }
    if let Some(pin) = cfg.pin.as_ref() {
        if pin.trim().is_empty() {
            cfg.pin = None;
        }
    }
}

/// 本机局域网 IPv4 地址，已排除 Hyper-V / WSL / VPN 等虚拟网卡。
///
/// 关于页的「本机信息」用；排查互通问题时，这串地址就是对端应该连上的那个。
pub fn local_ips() -> Vec<String> {
    net::lan_ipv4_candidates()
        .iter()
        .map(|ip| ip.to_string())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_cfg_path(tag: &str) -> String {
        std::env::temp_dir()
            .join(format!("l78z-cfg-{tag}-{}.json", std::process::id()))
            .to_string_lossy()
            .into()
    }

    #[test]
    fn missing_file_yields_defaults() {
        let path = temp_cfg_path("missing");
        let _ = std::fs::remove_file(&path);

        let cfg = load_config(path.clone()).unwrap();
        assert_eq!(cfg.port, DEFAULT_PORT);
        assert_eq!(cfg.pin, None);
        assert!(cfg.verify_checksums);
        assert!(!cfg.ls_compat_enabled);
        // 默认配置不该写盘，否则每次打开设置页都会留一个文件。
        assert!(!Path::new(&path).exists());

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn save_then_load_roundtrip() {
        let path = temp_cfg_path("roundtrip");

        let mut cfg = AppConfig::default();
        cfg.device_name = "客厅电脑".into();
        cfg.port = 12345;
        cfg.pin = Some("8888".into());
        cfg.verify_checksums = false;

        save_config(path.clone(), cfg.clone()).unwrap();
        let loaded = load_config(path.clone()).unwrap();
        assert_eq!(loaded, cfg);

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn corrupt_file_falls_back_to_defaults_and_keeps_backup() {
        let path = temp_cfg_path("corrupt");
        std::fs::write(&path, "{ this is not json").unwrap();

        let cfg = load_config(path.clone()).unwrap();
        assert_eq!(cfg.port, DEFAULT_PORT);

        // 坏文件要留档，不能直接删掉——里面可能有用户填过的信息。
        assert!(Path::new(&format!("{path}.bak")).exists());

        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_file(format!("{path}.bak"));
    }

    #[test]
    fn sanitize_fixes_unusable_values() {
        let mut cfg = AppConfig {
            device_name: "   ".into(),
            port: 0,
            pin: Some("  ".into()),
            ..AppConfig::default()
        };
        sanitize(&mut cfg);

        assert_ne!(cfg.device_name.trim(), "");
        assert_eq!(cfg.port, DEFAULT_PORT);
        assert_eq!(cfg.pin, None);
    }

    #[test]
    fn local_ips_are_non_empty_and_ipv4() {
        // 本机至少有一块真实网卡；即便开发机只有回环，也不该返回非 IPv4 文本。
        for ip in local_ips() {
            assert!(ip.parse::<std::net::Ipv4Addr>().is_ok(), "非法 IPv4: {ip}");
        }
    }
}
