import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/config.dart';
import 'frb_util.dart';

/// 一个开源组件条目。
class _Lib {
  final String name;
  final String version;
  final String license;

  const _Lib(this.name, this.version, this.license);
}

/// Dart / Flutter 侧依赖。版本取自 pubspec.lock 的实际锁定值。
const List<_Lib> _dartLibs = [
  _Lib('flutter_rust_bridge', '2.13.0', 'MIT'),
  _Lib('package_info_plus', '10.2.2', 'MIT'),
  _Lib('file_picker', '13.1.0', 'MIT'),
  _Lib('path_provider', '2.1.6', 'BSD-3-Clause'),
  _Lib('lunar', '1.7.8', 'MIT'),
  _Lib('freezed_annotation', '3.1.0', 'MIT'),
  _Lib('json_annotation', '4.12.0', 'MIT'),
  _Lib('intl', '0.20.3', 'BSD-3-Clause'),
  _Lib('cupertino_icons', '1.0.9', 'MIT'),
];

/// Rust 侧直接依赖。版本取自 rust/Cargo.lock 的实际锁定值。
const List<_Lib> _rustLibs = [
  _Lib('axum', '0.8.9', 'MIT'),
  _Lib('reqwest', '0.12.28', 'MIT / Apache-2.0'),
  _Lib('tokio', '1.53.2', 'MIT'),
  _Lib('serde / serde_json', '1.0.229 / 1.0.152', 'MIT / Apache-2.0'),
  _Lib('rapidocr-core', '0.2.2', 'Apache-2.0'),
  _Lib('rxing', '0.9.3', 'MIT'),
  _Lib('qrcode', '0.14.1', 'MIT'),
  _Lib('image', '0.25.8', 'MIT / Apache-2.0'),
  _Lib('local-ip-address', '0.6.13', 'MIT'),
  _Lib('chrono', '0.4.45', 'MIT / Apache-2.0'),
  _Lib('anyhow', '1.0.75', 'MIT / Apache-2.0'),
  _Lib('futures-util', '0.3.29', 'MIT / Apache-2.0'),
  _Lib('tokio-util', '0.7.20', 'MIT'),
];

/// 内置字体。均为 SIL Open Font License 1.1——可自由商用、嵌入、再分发，
/// 分发衍生版本时需保留原许可与版权声明。
const List<_Lib> _fontLibs = [
  _Lib('LXGW WenKai GB（霞鹜文楷）', 'GB Regular / Medium', 'SIL OFL 1.1'),
  _Lib('Noto Sans SC（思源黑体）', 'Regular', 'SIL OFL 1.1'),
  _Lib('Noto Serif SC（思源宋体）', 'Regular', 'SIL OFL 1.1'),
];

/// 关于页：版本、本机信息、开源许可、第三方组件。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  String _buildNumber = '';
  List<String> _ips = [];
  int _port = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        PackageInfo.fromPlatform(),
        localIps(),
        loadAppConfig(),
      ]);
      final info = results[0] as PackageInfo;
      final ips = results[1] as List<String>;
      final cfg = results[2] as AppConfig;
      if (!mounted) return;
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
        _ips = ips;
        _port = cfg.port;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _libList(List<_Lib> libs) => Card(
        child: Column(
          children: [
            for (var i = 0; i < libs.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                dense: true,
                title: Text(libs[i].name),
                subtitle: Text(libs[i].license),
                trailing: Text(libs[i].version),
              ),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ips = _ips.isEmpty ? l10n.aboutNoLan : _ips.join('  ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.swap_horiz, size: 64),
                  const SizedBox(height: 12),
                  Text(
                    '互传助手',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _version.isEmpty
                        ? ''
                        : l10n.aboutVersion(_version, _buildNumber),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(l10n.aboutLoadFailed),
                subtitle: Text(_error!),
                trailing: const Icon(Icons.refresh),
                onTap: _load,
              ),
            ),
          _sectionTitle(l10n.aboutSectionDevice),
          Card(
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(l10n.aboutLocalIp),
                  subtitle: Text(ips),
                ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(l10n.aboutListenPort),
                  subtitle: Text('$_port'),
                ),
                const Divider(height: 1),
                // 设备指纹要等 LocalSend 兼容层接入后才会生成，
                // 这里先占位，避免显示一个并不存在的值。
                ListTile(
                  dense: true,
                  title: Text(l10n.aboutFingerprint),
                  subtitle: Text(l10n.aboutFingerprintHint),
                  trailing: const Text('—'),
                ),
              ],
            ),
          ),
          _sectionTitle(l10n.aboutSectionLicense),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aboutLicenseTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.aboutLicenseBody),
                ],
              ),
            ),
          ),
          _sectionTitle(l10n.aboutSectionThirdParty),
          Text('Dart / Flutter', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          _libList(_dartLibs),
          const SizedBox(height: 16),
          Text('Rust', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          _libList(_rustLibs),
          const SizedBox(height: 16),
          Text(l10n.aboutSectionFonts,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          _libList(_fontLibs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
