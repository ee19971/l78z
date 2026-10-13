import 'package:flutter/material.dart';

import 'lan_transfer_page.dart';
import 'qr_gen_page.dart';
import 'scan_page.dart';
import 'settings_page.dart';

/// 工具页：扫一扫 / 二维码生成 / 局域网传输 / 设置 入口。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.qr_code_scanner, '扫一扫', '扫码 / 选图解码 / 图片 OCR', const ScanPage()),
      (
        Icons.qr_code_2,
        '二维码 / 条形码',
        '14 种格式，支持 WiFi、名片等模板',
        const QrGenPage(),
      ),
      (
        Icons.swap_horiz,
        '局域网传输',
        '手机与电脑互传文本与文件',
        const LanTransferPage(),
      ),
      (Icons.settings_outlined, '设置', '互传配置、版本与开源许可', const SettingsPage()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
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
