import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/rust/api/countdown.dart';
import 'frb_util.dart';

/// 预设主题色。桌面小部件共用事件里的 color 值，两边观感才一致。
const List<String> _presetColors = [
  '#6750A4', // 紫（默认）
  '#E53935', // 红
  '#FB8C00', // 橙
  '#FDD835', // 黄
  '#43A047', // 绿
  '#1E88E5', // 蓝
  '#00897B', // 青
  '#8E24AA', // 紫红
  '#6D4C41', // 棕
  '#546E7A', // 蓝灰
  '#000000', // 黑
];

/// 把 `#RRGGBB` 解析成 [Color]；格式不对时退回默认色。
///
/// 小部件那边也认这一串，所以解析规则必须与 Kotlin 侧保持一致。
Color hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  if (h.length != 6) return const Color(0xFF6750A4);
  final v = int.tryParse(h, radix: 16);
  return v == null ? const Color(0xFF6750A4) : Color(0xFF000000 | v);
}

/// 日期转 `YYYY-MM-DD`。与 Rust 侧 `parse_date` 的解析格式严格对应。
String formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 倒数日页：事件列表 + 人生进度。
///
/// 数据存 Rust 侧 JSON，桌面小部件读同一份文件；每次改动后都要敲一下
/// 原生通道，否则桌面上的天数不会跟着变。
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  List<CountdownEvent> _events = [];
  LifeProfile? _life;
  LifeProgress? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await countdownFilePath();
      final events = await countdownEvents(path: path);
      final life = await countdownLife(path: path);
      final progress = await countdownLifeProgress(path: path);
      if (!mounted) return;
      setState(() {
        _events = events;
        _life = life;
        _progress = progress;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 落盘并同步桌面小部件。
  Future<void> _apply(Future<List<CountdownEvent>> Function(String path) op) async {
    try {
      final path = await countdownFilePath();
      final events = await op(path);
      if (!mounted) return;
      setState(() => _events = events);
      // 存成功后再通知原生；通知失败不该影响已经落盘的数据。
      await refreshCountdownWidgets();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.cdOpFailed('$e'))));
    }
  }

  Future<void> _openEditor([CountdownEvent? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventEditorPage(existing: existing)),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(CountdownEvent ev) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cdDeleteTitle(ev.title)),
        content: Text(l10n.cdDeleteMsg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _apply((path) => countdownDelete(path: path, id: ev.id));
    }
  }

  Future<void> _editLife() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LifeEditorPage(existing: _life)),
    );
    if (saved == true) await _load();
  }

  /// 大数字：按模式决定显示「剩余」还是「已过」的绝对值。
  String _dayNumber(CountdownEvent ev) {
    final d = ev.daysLeft.toInt();
    switch (ev.mode) {
      case CountMode.countup:
        return '${d.abs()}';
      case CountMode.yearly:
      case CountMode.countdown:
        return '${d.abs()}';
    }
  }

  /// 数字下方固定一个「天」字。
  ///
  /// 状态词不放这里——「天 · 还剩」读起来语序是反的。它挪到日期那一行，
  /// 排版就变成「128 / 天 / 还剩 · 2026-12-20」，一眼能读通。
  String _dayCaption(CountdownEvent ev) =>
      AppLocalizations.of(context)!.commonDayUnit;

  /// 状态词：还剩 / 已过 / 还有 / 距下次 / 就是今天。
  String _statusLabel(CountdownEvent ev) {
    final l10n = AppLocalizations.of(context)!;
    final d = ev.daysLeft.toInt();
    switch (ev.mode) {
      case CountMode.countdown:
        if (d > 0) return l10n.cdRemain;
        if (d == 0) return l10n.cdToday;
        return l10n.cdPassed;
      case CountMode.countup:
        if (d < 0) return l10n.cdPassed;
        if (d == 0) return l10n.cdToday;
        return l10n.cdHas;
      case CountMode.yearly:
        if (d > 0) return l10n.cdUntilNext;
        return l10n.cdToday;
    }
  }

  String _modeLabel(CountMode mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case CountMode.countdown:
        return l10n.cdModeCountdown;
      case CountMode.countup:
        return l10n.cdModeCountup;
      case CountMode.yearly:
        return l10n.cdModeYearly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cdTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.cdAdd),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(l10n.cdLoadFailed('$_error'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _lifeCard(),
        const SizedBox(height: 16),
        if (_events.isEmpty) _emptyState() else ...[
          Text(AppLocalizations.of(context)!.cdTotal(_events.length),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final ev in _events) _eventCard(ev),
        ],
      ],
    );
  }

  Widget _emptyState() => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)!.cdEmpty,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.cdEmptyHint,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _lifeCard() {
    final l10n = AppLocalizations.of(context)!;
    final progress = _progress;
    if (progress == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cake_outlined, size: 32),
          title: Text(l10n.cdLifeTitle),
          subtitle: Text(l10n.cdLifeSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editLife,
        ),
      );
    }

    final pct = progress.percent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cake_outlined),
                const SizedBox(width: 8),
                Text(l10n.cdLifeTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                    onPressed: _editLife, child: Text(l10n.cdLifeEdit)),
              ],
            ),
            if (_life?.quote.isNotEmpty ?? false) ...[
              const SizedBox(height: 2),
              Text(
                l10n.cdQuote(_life!.quote),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.cdLifePassed(pct.toStringAsFixed(2))),
                Text(l10n.cdLifeLived(progress.livedDays.toInt())),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cdLifeRemaining(
                  _life?.lifespan ?? 0, progress.daysLeft.toInt()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(CountdownEvent ev) {
    final color = hexColor(ev.color);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditor(ev),
        onLongPress: () => _showMenu(ev),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 左侧色块：天数大字，一眼扫过去就是这排数字。
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dayNumber(ev),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      _dayCaption(ev),
                      style: TextStyle(fontSize: 9, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ev.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (ev.pinned) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.push_pin, size: 14, color: Colors.orange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _tag(_modeLabel(ev.mode), color),
                        const SizedBox(width: 6),
                        Text(
                          '${_statusLabel(ev)} · ${ev.date}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (ev.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ev.note,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );

  void _showMenu(CountdownEvent ev) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(ev.pinned ? l10n.cdUnpin : l10n.cdPin),
              subtitle: Text(l10n.cdPinHint),
              onTap: () {
                Navigator.pop(ctx);
                _apply((path) => countdownTogglePin(path: path, id: ev.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonEdit),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(ev);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.commonDelete,
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(ev);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 新增 / 编辑一条倒数日。
class EventEditorPage extends StatefulWidget {
  final CountdownEvent? existing;

  const EventEditorPage({super.key, this.existing});

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late CountMode _mode;
  late String _color;
  late bool _pinned;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ev = widget.existing;
    _title = TextEditingController(text: ev?.title ?? '');
    _note = TextEditingController(text: ev?.note ?? '');
    _mode = ev?.mode ?? CountMode.countdown;
    _color = ev?.color ?? _presetColors.first;
    _pinned = ev?.pinned ?? false;
    _date = _parse(ev?.date) ?? DateTime.now();
  }

  DateTime? _parse(String? s) {
    if (s == null || s.length < 10) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.cdErrTitleRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await countdownFilePath();
      await countdownSave(
        path: path,
        event: CountdownEvent(
          id: widget.existing?.id ?? '',
          title: title,
          date: formatDate(_date),
          mode: _mode,
          color: _color,
          pinned: _pinned,
          note: _note.text.trim(),
          daysLeft: 0,
        ),
      );
      await refreshCountdownWidgets();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cdSaveFailed('$e'))));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? l10n.cdAdd : l10n.cdEditTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.cdFieldTitle,
              hintText: l10n.cdFieldTitleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(l10n.cdFieldTarget),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _pickDate,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CountMode>(
            initialValue: _mode,
            decoration: InputDecoration(
              labelText: l10n.cdFieldMode,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                  value: CountMode.countdown, child: Text(l10n.cdModeCountdownFull)),
              DropdownMenuItem(
                  value: CountMode.countup, child: Text(l10n.cdModeCountupFull)),
              DropdownMenuItem(
                  value: CountMode.yearly, child: Text(l10n.cdModeYearlyFull)),
            ],
            onChanged: _saving ? null : (v) => setState(() => _mode = v ?? CountMode.countdown),
          ),
          const SizedBox(height: 16),
          Text(l10n.cdFieldColor, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in _presetColors)
                GestureDetector(
                  onTap: _saving ? null : () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hexColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == hex ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _color == hex
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.cdFieldNote,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.cdPin),
            subtitle: Text(l10n.cdPinSwitchHint),
            value: _pinned,
            onChanged: _saving ? null : (v) => setState(() => _pinned = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置人生进度参数（出生日期 + 预期寿命）。
class LifeEditorPage extends StatefulWidget {
  final LifeProfile? existing;

  const LifeEditorPage({super.key, this.existing});

  @override
  State<LifeEditorPage> createState() => _LifeEditorPageState();
}

class _LifeEditorPageState extends State<LifeEditorPage> {
  late final TextEditingController _lifespan;
  late final TextEditingController _quote;
  DateTime? _birthday;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _lifespan = TextEditingController(text: (ex?.lifespan ?? 80).toString());
    _quote = TextEditingController(text: ex?.quote ?? '');
    _birthday = _parse(ex?.birthday) ?? DateTime(2000, 1, 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从没设置过时预填默认格言（跟随界面语言）；用户把文字删光后存的是
    // 空串，重新进入不再替他补——empty 判断就是干这个的。
    if (widget.existing == null && _quote.text.isEmpty) {
      _quote.text = AppLocalizations.of(context)!.cdDefaultQuote;
    }
  }

  DateTime? _parse(String? s) {
    if (s == null || s.length < 10) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  @override
  void dispose() {
    _lifespan.dispose();
    _quote.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    // 校验一律提到第一个 await 之前：那时 context 必然还活着，
    // 也就不必为「跨 async gap 使用 BuildContext」补 mounted 判断。
    final l10n = AppLocalizations.of(context)!;
    DateTime? birthday;
    var lifespan = 0;
    if (!clear) {
      birthday = _birthday;
      if (birthday == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.cdErrPickBirthday)));
        return;
      }
      lifespan = int.tryParse(_lifespan.text.trim()) ?? 0;
      if (lifespan <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.cdErrLifespan)));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final path = await countdownFilePath();
      if (clear) {
        await countdownSetLife(path: path, life: null);
      } else {
        await countdownSetLife(
          path: path,
          life: LifeProfile(
            birthday: formatDate(birthday!),
            lifespan: lifespan,
            // 用户清空格言就是想让它空着，原样存空串，别替他补默认值。
            quote: _quote.text.trim(),
          ),
        );
      }
      await refreshCountdownWidgets();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context)!.cdSaveFailed('$e'))));
      setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cdLifeSetupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: Text(l10n.cdBirthday),
              subtitle:
                  Text(_birthday == null ? l10n.cdNotSet : formatDate(_birthday!)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _saving ? null : _pickBirthday,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lifespan,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.cdLifespanField,
              helperText: l10n.cdLifespanHelp,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quote,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: l10n.cdQuoteField,
              helperText: l10n.cdQuoteHelp,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () => _save(),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => _save(clear: true),
              child: Text(l10n.cdClearLife,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}
