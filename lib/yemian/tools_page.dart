import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'lan_transfer_page.dart';
import 'qr_gen_page.dart';
import 'scan_page.dart';
import 'settings_page.dart';

/// 工具页：扫一扫 / 二维码生成 / 局域网传输 / 设置 入口。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        Icons.qr_code_scanner,
        l10n.toolsScan,
        l10n.toolsScanSub,
        const ScanPage(),
      ),
      (
        Icons.qr_code_2,
        l10n.toolsQr,
        l10n.toolsQrSub,
        const QrGenPage(),
      ),
      (
        Icons.swap_horiz,
        l10n.toolsLan,
        l10n.toolsLanSub,
        const LanTransferPage(),
      ),
      (
        Icons.settings_outlined,
        l10n.toolsSettings,
        l10n.toolsSettingsSub,
        const SettingsPage(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, title, subtitle, page) in items)
            Card(
              child: ListTile(
                leading: Icon(icon, size: 32),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => page),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
