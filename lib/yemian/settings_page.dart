import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../src/rust/api/config.dart';
import 'about_page.dart';
import 'frb_util.dart';

/// LocalSend 兼容层的默认端口，与官方 LocalSend 保持一致，便于互发现。
const int kLocalSendPort = 53317;

/// 设置页。
///
/// 目前只有「互传」一组配置。LocalSend 兼容层与自有协议并存：开关关掉时
/// 只走扫码配对，打开后进传输页会自动起第二套 server 并靠多播发现官方设备。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppConfig? _cfg;
  String? _loadError;
  bool _saving = false;

  bool _verifyChecksums = true;
  bool _lsCompatEnabled = false;

  final _deviceNameController = TextEditingController();
  final _portController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await loadAppConfig();
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _verifyChecksums = cfg.verifyChecksums;
        _lsCompatEnabled = cfg.lsCompatEnabled;
        _deviceNameController.text = cfg.deviceName;
        _portController.text = cfg.port.toString();
        _pinController.text = cfg.pin ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  /// 由当前输入框内容拼出待保存的配置。
  ///
  /// 设备名留空是有意的：交给 Rust 侧按主机名补默认值，比在 UI 里猜一个更准。
  AppConfig _collect() {
    final pin = _pinController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    return AppConfig(
      deviceName: _deviceNameController.text.trim(),
      // 端口解析失败或越界时退回默认值，避免存进一个监听不了的端口。
      port: (port == null || port < 1 || port > 65535) ? kLocalSendPort : port,
      pin: pin.isEmpty ? null : pin,
      verifyChecksums: _verifyChecksums,
      lsCompatEnabled: _lsCompatEnabled,
    );
  }

  Future<void> _save() async {
    if (_saving || _cfg == null) return;
    setState(() => _saving = true);
    try {
      final saved = await saveAppConfig(_collect());
      if (!mounted) return;
      setState(() {
        _cfg = saved;
        _deviceNameController.text = saved.deviceName;
        _portController.text = saved.port.toString();
        _pinController.text = saved.pin ?? '';
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadError != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('配置读取失败'),
                subtitle: Text(_loadError!),
                trailing: const Icon(Icons.refresh),
                onTap: _load,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('互传', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: cfg == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _deviceNameController,
                          decoration:
                              _decoration('设备名称', helper: '对方设备列表里显示的名字'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _decoration(
                            '监听端口',
                            helper: '默认 $kLocalSendPort。被占用时会自动改用其他端口，不影响互传',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          decoration: _decoration(
                            '传输 PIN（可选）',
                            helper: '留空表示不校验。设置后，对方必须输入才能推送文件',
                          ),
                        ),
                        const Divider(height: 32),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('校验文件哈希'),
                          subtitle:
                              const Text('收到文件后比对发送方提供的 SHA-256'),
                          value: _verifyChecksums,
                          onChanged: (v) =>
                              setState(() => _verifyChecksums = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用 LocalSend 兼容'),
                          subtitle: const Text(
                            '与官方 LocalSend 同一网络自动互通：不用扫码，进入传输页就会自动发现',
                          ),
                          value: _lsCompatEnabled,
                          onChanged: (v) => setState(() => _lsCompatEnabled = v),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text('关于', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, size: 32),
              title: const Text('关于互传助手'),
              subtitle: const Text('版本、开源许可与第三方组件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
