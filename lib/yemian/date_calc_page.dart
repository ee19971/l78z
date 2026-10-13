import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'festivals.dart';

/// 日期计算页：日期推算 / 日期间隔 / 时间推算。
///
/// 三种常见需求各占一个 tab：
///  - 日期推算：已知一个日期和相差天数，求目标日期；
///  - 日期间隔：已知两个日期，求相差天数；
///  - 时间推算：已知一个时间和相差时长，求目标时间。
///
/// 计算直接在 Dart 侧完成——结果不落盘、不进桌面部件，走 Rust 只是徒增一次
/// FFI 往返。天数口径与倒数日一致：**日历天差**，不看时区、不看小时，
/// 也就是 `2026-10-12` 到 `2026-10-13` 恒为 1 天，哪怕中间只隔了一小时。
class DateCalcPage extends StatefulWidget {
  const DateCalcPage({super.key});

  @override
  State<DateCalcPage> createState() => _DateCalcPageState();
}

class _DateCalcPageState extends State<DateCalcPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  // 日期推算
  DateTime _baseDate = DateTime.now();
  bool _baseLunar = false;
  final _daysCtrl = TextEditingController();

  // 日期间隔
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _intervalLunar = false;

  // 时间推算
  DateTime _baseTime = DateTime.now();
  final _hoursCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();

  static final DateFormat _timeFormat = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void dispose() {
    _tab.dispose();
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  /// 日期行显示文本：公历 `2026年10月12日 周一` / 农历 `二〇二六年九月初三 星期一`。
  ///
  /// 开关只切换**显示**，日期选择器始终走公历——农历日期选择器要么得自己
  /// 拼闰月规则，要么得引一整套控件，而日常用到的场景九成是「我知道公历
  /// 哪天，只是想看看农历是什么」。
  String _dateLabel(DateTime date, {required bool lunar}) {
    final info = DayInfo.of(date);
    if (!lunar) {
      return '${date.year}年${date.month}月${date.day}日 ${info.weekText}';
    }
    final l = info.lunar;
    return '农历${l.getYearInChinese()}年${l.getMonthInChinese()}'
        '${l.getDayInChinese()} ${info.weekText}';
  }

  /// 补上未填的输入框，空串和非法字符都当成 0。
  int _toInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  // -----------------------------------------------------------------------
  // 日期推算
  // -----------------------------------------------------------------------

  /// 起始日期 + 相差天数 = 目标日期。天数可为负，表示往回推。
  DateTime? get _pushedDate {
    final n = _toInt(_daysCtrl);
    if (_daysCtrl.text.trim().isEmpty) return null;
    return _baseDate.add(Duration(days: n));
  }

  Future<void> _pickBaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baseDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _baseDate = picked);
  }

  Widget _buildDatePush() {
    final target = _pushedDate;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dateRow(
          date: _baseDate,
          lunar: _baseLunar,
          trailing: _lunarSwitch(
            value: _baseLunar,
            onChanged: (v) => setState(() => _baseLunar = v),
          ),
          onTap: _pickBaseDate,
        ),
        _inputRow(
          label: '相差的日子',
          unit: '天',
          controller: _daysCtrl,
          hint: '可为负数',
        ),
        const Divider(height: 32),
        if (target != null) _resultCard('推算结果', _dateLabel(target, lunar: false)),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 日期间隔
  // -----------------------------------------------------------------------

  /// 终点减起点的日历天数，终点在前时为负数。
  int get _intervalDays {
    final a = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final b = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return b.difference(a).inDays;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildDateInterval() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dateRow(
          date: _startDate,
          lunar: _intervalLunar,
          trailing: _lunarSwitch(
            value: _intervalLunar,
            onChanged: (v) => setState(() => _intervalLunar = v),
          ),
          onTap: () => _pickDate(isStart: true),
        ),
        _dateRow(
          date: _endDate,
          lunar: _intervalLunar,
          onTap: () => _pickDate(isStart: false),
        ),
        const Divider(height: 32),
        _resultCard('相差的日子', '${_intervalDays.abs()} 天'),
        if (_intervalDays != 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _intervalDays > 0
                  ? '终点比起点晚 $_intervalDays 天'
                  : '终点比起点早 ${-_intervalDays} 天',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 时间推算
  // -----------------------------------------------------------------------

  /// 起始时间 + 时长 = 目标时间。时长可为负，表示往回推。
  DateTime? get _pushedTime {
    if (_hoursCtrl.text.trim().isEmpty && _minutesCtrl.text.trim().isEmpty) {
      return null;
    }
    return _baseTime.add(
      Duration(hours: _toInt(_hoursCtrl), minutes: _toInt(_minutesCtrl)),
    );
  }

  Future<void> _pickBaseTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _baseTime,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_baseTime),
    );
    if (pickedTime == null) return;
    setState(() {
      _baseTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _buildTimePush() {
    final target = _pushedTime;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dateRow(
          date: _baseTime,
          lunar: false,
          text: _timeFormat.format(_baseTime),
          onTap: _pickBaseTime,
        ),
        _inputRow(label: '相差的小时', unit: '时', controller: _hoursCtrl),
        _inputRow(label: '相差的分钟', unit: '分', controller: _minutesCtrl),
        const Divider(height: 32),
        if (target != null) _resultCard('推算结果', _timeFormat.format(target)),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // 共用行组件
  // -----------------------------------------------------------------------

  /// 日期行：左侧图标 + 日期文本，右侧可选控件（农历开关）。
  Widget _dateRow({
    required DateTime date,
    required bool lunar,
    Widget? trailing,
    String? text,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(text ?? _dateLabel(date, lunar: lunar)),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// 数字输入行：`相差的____天`，右侧下划线输入框。
  Widget _inputRow({
    required String label,
    required String unit,
    required TextEditingController controller,
    String? hint,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.edit_calendar_outlined),
        title: Text(label),
        trailing: SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint ?? '',
              suffixText: unit,
              border: const UnderlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }

  Widget _lunarSwitch({required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('农历', style: Theme.of(context).textTheme.bodySmall),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  /// 结果卡片：大字数值，一目了然。
  Widget _resultCard(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日期计算'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '日期推算'),
            Tab(text: '日期间隔'),
            Tab(text: '时间推算'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildDatePush(),
          _buildDateInterval(),
          _buildTimePush(),
        ],
      ),
    );
  }
}
