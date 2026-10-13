import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../src/rust/api/qr.dart';

/// 一个条码格式。
class _Format {
  /// 传给 Rust 的 rxing 格式名，与解码结果里的 format 字段完全一致。
  final String id;

  final String name;

  /// 输入约束，选中该格式时显示在输入框下方。
  ///
  /// 这些不是建议而是硬校验：字符集或位数不对时 zxing 直接抛异常，
  /// 所以得提前告诉用户，而不是等他点完生成再报错。
  final String hint;

  /// 本应用的「扫一扫」能否识别。false 表示只能生成、扫不回来。
  final bool selfScannable;

  const _Format(
    this.id,
    this.name,
    this.hint, {
    this.selfScannable = true,
  });

  /// 是否二维矩阵码（含堆叠式的 PDF 417）。
  ///
  /// 决定画布比例：矩阵码用正方形，一维码则是扁长条。
  bool get isMatrix =>
      const {'QR_CODE', 'DATA_MATRIX', 'AZTEC', 'PDF_417'}.contains(id);
}

/// 格式分组。
class _FormatGroup {
  final String title;
  final List<_Format> formats;

  const _FormatGroup(this.title, this.formats);
}

const List<_FormatGroup> _groups = [
  _FormatGroup('二维码 / 矩阵码', [
    _Format('QR_CODE', '二维码', '任意文本、网址、中文都可以'),
    _Format('DATA_MATRIX', 'Data Matrix', '任意文本，体积小，常印在小零件上'),
    _Format('AZTEC', 'Aztec', '任意文本，常见于登机牌、火车票'),
  ]),
  _FormatGroup('堆叠二维', [
    _Format('PDF_417', 'PDF 417', '任意文本，可存较长内容，常见于各类证件'),
  ]),
  _FormatGroup('商品条码', [
    _Format('EAN_13', 'EAN-13', '12 或 13 位数字，末位是校验位'),
    _Format('EAN_8', 'EAN-8', '7 或 8 位数字'),
    _Format('UPC_A', 'UPC-A', '11 或 12 位数字'),
    // UPC-E：rxing 能生成、也校验过末位，但它的解码器读不回来
    // （默认 / TryHarder / 限定 reader / PureBarcode 四种策略一律
    // NotFoundException），换别的扫码工具则正常。如实标注，不假装能用。
    _Format('UPC_E', 'UPC-E', '7 或 8 位数字，首位须为 0 或 1',
        selfScannable: false),
  ]),
  _FormatGroup('物流 / 工业', [
    _Format('CODE_128', 'Code 128', '任意 ASCII 文本，快递单最常用'),
    // $ 在 Dart 字符串字面量里要转义
    _Format('CODE_39', 'Code 39', '限 0-9 A-Z 与 - . \$ / + % 和空格'),
    _Format('CODE_93', 'Code 93', '任意 ASCII 文本'),
    _Format('ITF', 'ITF', '偶数位数字，常见于外箱包装'),
    _Format('CODABAR', 'Codabar', '数字加 A/B/C/D 作起止符，如 A123456B'),
  ]),
  _FormatGroup('其他', [
    _Format('TELEPEN', 'Telepen', '任意 ASCII 文本，较少使用',
        selfScannable: false),
  ]),
];

final List<_Format> _allFormats = _groups.expand((g) => g.formats).toList();

/// 内容模板：填表单，由 _buildPayload 拼成标准格式的文本再去生成。
enum _Template { custom, wifi, url, vcard, phone, sms, email, calendar, geo }

const Map<_Template, String> _templateLabel = {
  _Template.custom: '自定义',
  _Template.wifi: 'WiFi',
  _Template.url: '网址',
  _Template.vcard: '名片',
  _Template.phone: '电话',
  _Template.sms: '短信',
  _Template.email: '邮件',
  _Template.calendar: '日历',
  _Template.geo: '位置',
};

/// 二维码 / 条形码生成页。
class QrGenPage extends StatefulWidget {
  const QrGenPage({super.key});

  @override
  State<QrGenPage> createState() => _QrGenPageState();
}

class _QrGenPageState extends State<QrGenPage> {
  /// 按 key 复用输入框，省掉二十来个字段和同样长的 dispose 列表。
  final Map<String, TextEditingController> _ctrls = {};

  _Template _template = _Template.custom;
  _Format _format = _allFormats.first;
  String _wifiSecurity = 'WPA';
  DateTime? _calStart;
  DateTime? _calEnd;

  Uint8List? _png;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _c(String key) =>
      _ctrls.putIfAbsent(key, () => TextEditingController());

  /// 当前可选格式：自定义时全部 14 种，选了内容模板就锁到二维码。
  ///
  /// vCard、日历这类结构化内容一维条码根本装不下，放开选择只会让用户
  /// 拼出一个必然生成失败的组合。
  List<_Format> get _availableFormats =>
      _template == _Template.custom ? _allFormats : [_allFormats.first];

  // ---------------------------------------------------------------- 组装内容

  /// 转义 WiFi 与 vCard 字段里的分隔符。
  ///
  /// SSID 里出现分号、冒号很常见（路由器默认名就带），不转义的话扫码方
  /// 解析出来的网络名会是残缺的。
  String _esc(String s) => s.replaceAll(RegExp(r'[\\;,:"]'), r'\\$0');

  /// 手机号只保留数字与开头的 +，去掉空格、横线等排版字符。
  String _digits(String s) {
    final t = s.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    // 中间的 + 会破坏号码结构，只允许出现在开头。
    return t.startsWith('+') ? '+${t.replaceAll('+', '')}' : t;
  }

  /// 由当前模板与输入内容拼出待生成的文本；内容不完整时返回 null。
  String? _buildPayload() {
    String need(String key, String label) {
      final v = _c(key).text.trim();
      return v.isEmpty ? throw _FormError('请填写$label') : v;
    }

    switch (_template) {
      case _Template.custom:
        final t = _c('custom').text.trim();
        if (t.isEmpty) throw _FormError('请填写内容');
        return t;

      case _Template.wifi:
        final ssid = need('wifiSsid', '网络名称');
        if (_wifiSecurity == 'nopass') {
          return 'WIFI:T:nopass;S:${_esc(ssid)};;';
        }
        return 'WIFI:T:$_wifiSecurity;S:${_esc(ssid)};'
            'P:${_esc(_c('wifiPass').text)};;';

      case _Template.url:
        final url = need('url', '网址');
        // 不带 scheme 时补上 https://，否则很多扫码应用会当成纯文本。
        return RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(url)
            ? url
            : 'https://$url';

      case _Template.vcard:
        final name = need('vcName', '姓名');
        final buf = StringBuffer()
          ..writeln('BEGIN:VCARD')
          ..writeln('VERSION:3.0')
          ..writeln('N:$name')
          ..writeln('FN:$name');
        final phone = _c('vcPhone').text.trim();
        if (phone.isNotEmpty) buf.writeln('TEL;TYPE=CELL:${_digits(phone)}');
        final email = _c('vcEmail').text.trim();
        if (email.isNotEmpty) buf.writeln('EMAIL:$email');
        final org = _c('vcOrg').text.trim();
        if (org.isNotEmpty) buf.writeln('ORG:$org');
        final title = _c('vcTitle').text.trim();
        if (title.isNotEmpty) buf.writeln('TITLE:$title');
        final url = _c('vcUrl').text.trim();
        if (url.isNotEmpty) buf.writeln('URL:$url');
        buf.writeln('END:VCARD');
        return buf.toString();

      case _Template.phone:
        final phone = _digits(need('phone', '电话号码'));
        if (phone.isEmpty) throw _FormError('电话号码里没有可用数字');
        return 'tel:$phone';

      case _Template.sms:
        final to = _digits(need('smsTo', '收件号码'));
        if (to.isEmpty) throw _FormError('收件号码里没有可用数字');
        return 'SMSTO:$to:${_c('smsBody').text}';

      case _Template.email:
        final to = need('mailTo', '收件邮箱');
        return 'MATMSG:TO:$to;SUB:${_c('mailSubject').text};'
            'BODY:${_c('mailBody').text};;';

      case _Template.calendar:
        final summary = need('calTitle', '标题');
        final start = _calStart ?? (throw _FormError('请选择开始时间'));
        // 没选结束时间就按开始后一小时算：比要求用户必须填更顺手，
        // 也避免拼出零值时间戳。
        final endTime = _calEnd ?? start.add(const Duration(hours: 1));
        return 'BEGIN:VEVENT'
            '\nSUMMARY:$summary'
            '\nDTSTART:${_icsTime(start)}'
            '\nDTEND:${_icsTime(endTime)}'
            '${_locationSuffix()}'
            '\nEND:VEVENT';

      case _Template.geo:
        final lat = double.tryParse(_c('geoLat').text.trim());
        final lng = double.tryParse(_c('geoLng').text.trim());
        if (lat == null || lng == null) {
          throw _FormError('经纬度必须是数字');
        }
        return 'geo:$lat,$lng';
    }
  }

  String _locationSuffix() {
    final loc = _c('calLocation').text.trim();
    return loc.isEmpty ? '' : '\nLOCATION:$loc';
  }

  String _icsTime(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}'
        'T${p(dt.hour)}${p(dt.minute)}${p(dt.second)}';
  }

  // ------------------------------------------------------------------ 动作

  Future<void> _generate() async {
    final String payload;
    try {
      payload = _buildPayload()!;
    } on _FormError catch (e) {
      setState(() {
        _png = null;
        _error = e.message;
      });
      return;
    } catch (e) {
      setState(() {
        _png = null;
        _error = '$e';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final matrix = _format.isMatrix;
      final png = await generateBarcodePng(
        format: _format.id,
        text: payload,
        width: matrix ? 360 : 480,
        height: matrix ? 360 : 200,
      );
      setState(() => _png = png);
    } catch (e) {
      setState(() => _png = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickStart() async {
    final dt = await _pickDateTime(_calStart);
    if (dt != null) setState(() => _calStart = dt);
  }

  Future<void> _pickEnd() async {
    final dt = await _pickDateTime(_calEnd ?? _calStart);
    if (dt != null) setState(() => _calEnd = dt);
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime.now()),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '未设置';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${p(dt.month)}-${p(dt.day)} ${p(dt.hour)}:${p(dt.minute)}';
  }

  // -------------------------------------------------------------------- UI

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            helperText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _dateTimeTile(String label, DateTime? value, VoidCallback onTap) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(label),
        subtitle: Text(_fmtTime(value)),
        trailing: const Icon(Icons.event),
        onTap: onTap,
      );

  /// 格式选择：只有自定义模板才出现，按分类折叠展示。
  ///
  /// 选了内容模板时可用格式只剩二维码，因此除「二维码 / 矩阵码」外的分组
  /// 会整体隐藏，而不是摆一堆点不动的选项。
  List<Widget> _formatPicker() {
    final available = _availableFormats;
    return [
      for (final g in _groups)
        if (g.formats.any(available.contains)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(g.title, style: Theme.of(context).textTheme.bodySmall),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in g.formats)
                if (available.contains(f))
                  ChoiceChip(
                    label: Text(f.name),
                    selected: f.id == _format.id,
                    onSelected: (_) => setState(() => _format = f),
                  ),
            ],
          ),
        ],
      // 约束必须紧跟着格式按钮显示：这些不是建议而是硬校验，
      // 不提前说清楚，用户只能在点完生成后看到一条看不懂的英文报错。
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _formatHint(_format),
      ),
    ];
  }

  /// 选中格式的说明：能装什么内容，以及能不能被本应用扫回来。
  Widget _formatHint(_Format f) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${f.name}（${f.isMatrix ? '二维' : '一维'}）',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('内容要求：${f.hint}'),
            if (!f.selfScannable) ...[
              const SizedBox(height: 8),
              Text(
                '注意：${f.name} 只能生成，本应用的扫一扫识别不了，'
                '用其他扫码工具可以正常扫。',
                style: TextStyle(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _templateForm() {
    switch (_template) {
      case _Template.custom:
        return [
          // 提示跟着选中格式走：选了 EAN-13 就直接说要 12/13 位数字，
          // 而不是笼统一句"任意文本"——那会让人以为随便输都能生成。
          _field('内容', _c('custom'), hint: _format.hint),
          ..._formatPicker(),
        ];

      case _Template.wifi:
        return [
          _field('网络名称 (SSID)', _c('wifiSsid')),
          _field('密码', _c('wifiPass'),
              hint: '加密方式选「无密码」时留空'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _wifiSecurity,
              decoration: const InputDecoration(
                labelText: '加密方式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'nopass', child: Text('无密码')),
              ],
              onChanged: (v) => setState(() => _wifiSecurity = v ?? 'WPA'),
            ),
          ),
        ];

      case _Template.url:
        return [
          _field('网址', _c('url'),
              hint: '例如 example.com，不写开头会自动补 https://'),
        ];

      case _Template.vcard:
        return [
          _field('姓名', _c('vcName')),
          _field('手机', _c('vcPhone'), keyboardType: TextInputType.phone),
          _field('邮箱', _c('vcEmail'), keyboardType: TextInputType.emailAddress),
          _field('公司', _c('vcOrg')),
          _field('职位', _c('vcTitle')),
          _field('网址', _c('vcUrl')),
        ];

      case _Template.phone:
        return [
          _field('电话号码', _c('phone'),
              hint: '空格、横线会被自动去掉', keyboardType: TextInputType.phone),
        ];

      case _Template.sms:
        return [
          _field('收件号码', _c('smsTo'), keyboardType: TextInputType.phone),
          _field('短信内容', _c('smsBody'), maxLines: 3),
        ];

      case _Template.email:
        return [
          _field('收件邮箱', _c('mailTo'), keyboardType: TextInputType.emailAddress),
          _field('主题', _c('mailSubject')),
          _field('正文', _c('mailBody'), maxLines: 4),
        ];

      case _Template.calendar:
        return [
          _field('标题', _c('calTitle')),
          _dateTimeTile('开始时间', _calStart, _pickStart),
          _dateTimeTile('结束时间', _calEnd, _pickEnd),
          if (_calEnd == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 12),
              child: Text(
                '不选结束时间则按开始后 1 小时计算',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _field('地点', _c('calLocation')),
        ];

      case _Template.geo:
        return [
          _field('纬度', _c('geoLat'),
              hint: '例如 31.2304', keyboardType: TextInputType.number),
          _field('经度', _c('geoLng'),
              hint: '例如 121.4737', keyboardType: TextInputType.number),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('生成二维码 / 条形码')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('内容模板', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _Template.values)
                ChoiceChip(
                  label: Text(_templateLabel[t]!),
                  selected: _template == t,
                  onSelected: (_) => setState(() {
                    _template = t;
                    // 切到内容模板时把格式拉回二维码：vCard、日历这类结构化
                    // 内容一维条码根本装不下，留着之前选的 CODE_128 之类，
                    // 只会拼出一个必然生成失败的组合。
                    if (t != _Template.custom) _format = _allFormats.first;
                    _png = null;
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ..._templateForm(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_2),
              label: Text(_busy ? '生成中…' : '生成'),
              onPressed: _busy ? null : _generate,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    // Rust 抛上来的是 zxing 的英文异常，直接给用户看等于没说。
                    // 附上该格式的要求，才知道该改成什么样。
                    const SizedBox(height: 8),
                    Text(
                      '「${_format.name}」要求：${_format.hint}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_png != null) ...[
            const SizedBox(height: 20),
            Text('预览', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Image.memory(
                    _png!,
                    width: _format.isMatrix ? 260 : 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 输入内容不符合模板要求，属于需要用户修改输入的情况。
class _FormError implements Exception {
  final String message;

  const _FormError(this.message);

  @override
  String toString() => message;
}
