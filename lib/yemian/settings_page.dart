import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/config.dart';
import 'about_page.dart';
import 'app_settings.dart';
import 'city_picker.dart';
import 'frb_util.dart';
import 'timezone_data.dart';

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

  // 显示与地区：直接读单例内存值（main() 里已 load），改动也走单例，
  // MaterialApp 靠 notifyListeners 即时重建，这里只是同步显示状态。
  String? _cityName;
  // 带默认值而非 late：initState 里的加载是异步的，首帧 build 跑在加载
  // 完成之前，late 字段会直接 LateError 把设置页崩掉。
  double _fontScale = 1.0;
  String _fontFamily = 'system';
  String _themeColorId = kThemeColorDefault;

  final _deviceNameController = TextEditingController();
  final _portController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadDisplay();
  }

  Future<void> _loadDisplay() async {
    // 兜底再 load 一次：测试环境不跑 main()，单例可能还没读过 prefs。
    await AppSettingsModel.instance.load();
    if (!mounted) return;
    final sp = await SharedPreferences.getInstance();
    final loc = sp.getString(kCityLocation);
    setState(() {
      _fontScale = AppSettingsModel.instance.fontScale;
      _fontFamily = AppSettingsModel.instance.fontFamily;
      _themeColorId = AppSettingsModel.instance.themeColorId;
      _cityName = loc == null ? null : cityByLocation(loc).name;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.commonSaved)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.commonSaveFailed('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? helper}) => InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      );

  // -------------------------------------------------------------------------
  // 语言与地区 / 显示
  // -------------------------------------------------------------------------

  /// 当前语言的显示名；null 表示跟随系统。
  static String _localeLabel(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.setFollowSystem;
    if (locale.countryCode == 'CN') return l10n.setLanguageZh;
    return l10n.setLanguageEn;
  }

  static String _fontFamilyLabel(AppLocalizations l10n, String family) =>
      switch (family) {
        kFontFamilySans => l10n.setFontSans,
        kFontFamilySerif => l10n.setFontSerif,
        _ => l10n.setFontSystem,
      };

  /// 中国传统色的显示名，key 与 [kThemeColors] 一一对应。
  static String _themeColorLabel(AppLocalizations l10n, String id) =>
      switch (id) {
        'zhusha' => l10n.setThemeZhusha,
        'yanzhi' => l10n.setThemeYanzhi,
        'dailan' => l10n.setThemeDailan,
        'shiqing' => l10n.setThemeShiqing,
        'zhuqing' => l10n.setThemeZhuqing,
        'xiangse' => l10n.setThemeXiangse,
        _ => id,
      };

  /// 语言三选。pop 值用哨兵字符串区分「跟随系统」与「取消」：
  /// 两者返回值都是 null，光看返回值分不出来。
  Future<void> _pickLocale() async {
    final l10n = AppLocalizations.of(context)!;
    final cur = AppSettingsModel.instance.locale;
    final isZh = cur?.countryCode == 'CN';
    final isEn = cur?.languageCode == 'en';
    final picked = await showDialog<Object>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.setLanguage),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'system'),
            child: Row(children: [
              if (cur == null) const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              Text(l10n.setFollowSystem),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, const Locale('zh', 'CN')),
            child: Row(children: [
              if (isZh) const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              Text(l10n.setLanguageZh),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, const Locale('en')),
            child: Row(children: [
              if (isEn) const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              Text(l10n.setLanguageEn),
            ]),
          ),
        ],
      ),
    );
    if (picked == null) return; // 取消
    await AppSettingsModel.instance
        .setLocale(picked is Locale ? picked : null);
    if (mounted) setState(() {});
  }

  /// 时区城市：复用主页面的 73 首都弹层，选中写同一份 prefs。
  Future<void> _pickCity() async {
    final city = await showCityPickerSheet(context);
    if (city == null) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kCityLocation, city.location);
    if (mounted) setState(() => _cityName = city.name);
  }

  /// 字体族三选，每项带同字体渲染的预览文字。
  Future<void> _pickFontFamily() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.setFont),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'system'),
            child: _fontOptionContent(
              l10n,
              _fontFamily == 'system',
              l10n.setFontSystem,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, kFontFamilySans),
            child: _fontOptionContent(
              l10n,
              _fontFamily == kFontFamilySans,
              l10n.setFontSans,
              family: kFontFamilySans,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, kFontFamilySerif),
            child: _fontOptionContent(
              l10n,
              _fontFamily == kFontFamilySerif,
              l10n.setFontSerif,
              family: kFontFamilySerif,
            ),
          ),
        ],
      ),
    );
    if (picked == null) return; // 取消
    await AppSettingsModel.instance.setFontFamily(picked);
    if (mounted) setState(() => _fontFamily = picked);
  }

  /// 主题色六选：色点 + 传统色名，选中打勾。
  /// 换色走 AppSettingsModel 通知 MaterialApp 重建，全应用即时生效。
  Future<void> _pickThemeColor() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.setThemeColor),
        children: [
          for (final entry in kThemeColors.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, entry.key),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration:
                        BoxDecoration(color: entry.value, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_themeColorLabel(l10n, entry.key))),
                  if (entry.key == _themeColorId) const Icon(Icons.check, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return; // 取消
    await AppSettingsModel.instance.setThemeColor(picked);
    if (mounted) setState(() => _themeColorId = picked);
  }

  /// 字体选项内容：勾选 + 名称 + 同字体渲染的预览文字。
  Widget _fontOptionContent(
    AppLocalizations l10n,
    bool active,
    String label, {
    String? family,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (active) const Icon(Icons.check, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ]),
          const SizedBox(height: 4),
          Text(
            l10n.setFontPreview,
            style: TextStyle(
              fontSize: 13,
              fontFamily: family,
              fontFamilyFallback: const ['sans-serif'],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadError != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(l10n.setConfigLoadFailed),
                subtitle: Text(_loadError!),
                trailing: const Icon(Icons.refresh),
                onTap: _load,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(l10n.setRegionTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.setLanguage),
                  subtitle: Text(_localeLabel(l10n, AppSettingsModel.instance.locale)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickLocale,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(l10n.setTimeZoneCity),
                  subtitle: Text(_cityName ?? l10n.setAutoDetect),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickCity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setDisplayTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.setFontSize((_fontScale * 100).round())),
                      ),
                      Slider(
                        value: _fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: l10n.setFontSize((_fontScale * 100).round()),
                        onChanged: (v) => setState(() => _fontScale = v),
                        onChangeEnd: (v) =>
                            AppSettingsModel.instance.setFontScale(v),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: Text(l10n.setFont),
                  subtitle: Text(_fontFamilyLabel(l10n, _fontFamily)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickFontFamily,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.palette_outlined,
                      color: kThemeColors[_themeColorId]),
                  title: Text(l10n.setThemeColor),
                  subtitle: Text(_themeColorLabel(l10n, _themeColorId)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickThemeColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setSectionTransfer,
              style: Theme.of(context).textTheme.titleMedium),
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
                          decoration: _decoration(l10n.setDeviceName,
                              helper: l10n.setDeviceNameHelp),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: _decoration(
                            l10n.setPortLabel,
                            helper: l10n.setPortHelp(kLocalSendPort),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pinController,
                          obscureText: true,
                          decoration: _decoration(
                            l10n.setPinLabel,
                            helper: l10n.setPinHelp,
                          ),
                        ),
                        const Divider(height: 32),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.setVerifyHash),
                          subtitle: Text(l10n.setVerifyHashSub),
                          value: _verifyChecksums,
                          onChanged: (v) =>
                              setState(() => _verifyChecksums = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.setLsCompat),
                          subtitle: Text(l10n.setLsCompatSub),
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
                                : Text(l10n.commonSave),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setSectionAbout,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, size: 32),
              title: Text(l10n.setAboutTitle),
              subtitle: Text(l10n.setAboutSub),
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
