use std::net::{IpAddr, Ipv4Addr, UdpSocket};

/// 虚拟/隧道/热点网卡的名称特征：这些地址对端（手机）根本路由不到，
/// 绝不能写进配对二维码，否则扫码成功但发送时全部超时。
///
/// 命中即排除，匹配时统一转小写，因此中英文网卡名都能覆盖。
const VIRTUAL_IFACE_PATTERNS: &[&str] = &[
    // Hyper-V / WSL
    "vethernet",
    "veth",
    "wsl",
    "hyper-v",
    // VMWare / VirtualBox
    "vmware",
    "vmnet",
    "virtualbox",
    "vbox",
    // Linux 虚拟网桥 / 容器
    "virbr",
    "docker",
    "br-",
    "dummy",
    // 隧道与 VPN
    "tun",
    "tap",
    "tailscale",
    "zerotier",
    "hamachi",
    "wireguard",
    "wg-",
    "openvpn",
    "vpn",
    "isatap",
    "teredo",
    "wan miniport",
    // 与局域网传输无关的接口
    "loopback",
    "bluetooth",
    "蓝牙",
    "npcap",
];

fn is_virtual_iface(name: &str) -> bool {
    let lowered = name.to_lowercase();
    VIRTUAL_IFACE_PATTERNS
        .iter()
        .any(|pattern| lowered.contains(pattern))
}

fn is_private(v4: Ipv4Addr) -> bool {
    let o = v4.octets();
    o[0] == 10 || (o[0] == 172 && (16..=31).contains(&o[1])) || (o[0] == 192 && o[1] == 168)
}

/// 这个地址能不能写进二维码。
fn is_usable(name: &str, v4: Ipv4Addr) -> bool {
    !v4.is_loopback() && !v4.is_link_local() && !is_virtual_iface(name)
}

/// 通过 UDP 路由查找拿到"默认路由出口"的 IPv4。
///
/// `connect` 只做路由查表、不会真正发出任何数据包，因此离线环境同样可用；
/// 没有默认路由时返回 None。
fn outbound_ipv4() -> Option<Ipv4Addr> {
    let socket = UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:53").ok()?;
    match socket.local_addr().ok()?.ip() {
        IpAddr::V4(v4) => Some(v4),
        _ => None,
    }
}

/// 所有可用于局域网配对的 IPv4，越靠前越优先。
///
/// 优先级：
/// 1. 默认路由出口网卡（手机最可能访问到的那块真实网卡）
/// 2. 其余私网地址（排除虚拟网卡）
/// 3. 其余可用地址兜底
pub fn lan_ipv4_candidates() -> Vec<Ipv4Addr> {
    let mut picked: Vec<Ipv4Addr> = Vec::new();
    let push = |v4: Ipv4Addr, picked: &mut Vec<Ipv4Addr>| {
        if !picked.contains(&v4) {
            picked.push(v4);
        }
    };

    let ifas = local_ip_address::list_afinet_netifas().unwrap_or_default();

    // 1) 默认路由出口：本机真正上网的那块网卡
    if let Some(out) = outbound_ipv4() {
        let known_and_usable = ifas
            .iter()
            .any(|(name, ip)| *ip == IpAddr::V4(out) && is_usable(name, out));
        if known_and_usable {
            push(out, &mut picked);
        }
    }

    // 2) 私网地址，排除虚拟网卡
    for (name, ip) in &ifas {
        if let IpAddr::V4(v4) = ip {
            if is_usable(name, *v4) && is_private(*v4) {
                push(*v4, &mut picked);
            }
        }
    }

    // 3) 其余可用地址兜底
    for (name, ip) in &ifas {
        if let IpAddr::V4(v4) = ip {
            if is_usable(name, *v4) {
                push(*v4, &mut picked);
            }
        }
    }

    picked
}

/// 选择本机最适合局域网通信的 IPv4 地址（取候选列表首选项）。
pub fn lan_ipv4() -> Option<IpAddr> {
    lan_ipv4_candidates()
        .first()
        .map(|v4| IpAddr::V4(*v4))
}

pub fn device_name() -> String {
    if let Ok(name) = std::env::var("COMPUTERNAME") {
        if !name.is_empty() {
            return name;
        }
    }
    if let Ok(name) = std::env::var("HOSTNAME") {
        if !name.is_empty() {
            return name;
        }
    }
    "l78z-device".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn virtual_ifaces_are_rejected() {
        assert!(is_virtual_iface("vEthernet (Default Switch)"));
        assert!(is_virtual_iface("VMware Network Adapter VMnet1"));
        assert!(is_virtual_iface("VirtualBox Host-Only Network"));
        assert!(is_virtual_iface("蓝牙网络连接"));
        assert!(is_virtual_iface("Loopback Pseudo-Interface 1"));
        assert!(is_virtual_iface("tun0"));
        assert!(!is_virtual_iface("WLAN"));
        assert!(!is_virtual_iface("以太网"));
        assert!(!is_virtual_iface("Ethernet"));
    }

    #[test]
    fn link_local_and_loopback_are_rejected() {
        assert!(!is_usable("WLAN", Ipv4Addr::new(169, 254, 1, 1)));
        assert!(!is_usable("WLAN", Ipv4Addr::LOCALHOST));
        assert!(is_usable("WLAN", Ipv4Addr::new(192, 168, 0, 101)));
    }

    #[test]
    fn private_ranges_are_recognized() {
        assert!(is_private(Ipv4Addr::new(10, 1, 2, 3)));
        assert!(is_private(Ipv4Addr::new(172, 16, 0, 1)));
        assert!(is_private(Ipv4Addr::new(172, 31, 255, 255)));
        assert!(is_private(Ipv4Addr::new(192, 168, 0, 101)));
        assert!(!is_private(Ipv4Addr::new(172, 32, 0, 1)));
        assert!(!is_private(Ipv4Addr::new(203, 0, 113, 7)));
    }

    /// 真实环境冒烟测试：候选列表里绝不能出现虚拟网卡地址。
    /// （在开发机上会打印实际选择结果，便于排查"二维码 IP 不对"的问题。）
    #[test]
    fn candidates_exclude_virtual_adapters() {
        let cands = lan_ipv4_candidates();
        println!("lan_ipv4_candidates = {:?}", cands);
        for (name, ip) in local_ip_address::list_afinet_netifas().unwrap_or_default() {
            if let IpAddr::V4(v4) = ip {
                if !v4.is_loopback() && is_virtual_iface(&name) {
                    assert!(
                        !cands.contains(&v4),
                        "虚拟网卡 {name} 的地址 {v4} 不应出现在候选列表中"
                    );
                }
            }
        }
    }
}
