//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 主页面——可切换城市的时钟、今天历法信息、功能快捷入口。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'festival_prefs.dart';
import 'festival_scan.dart';
import 'festivals.dart';
import 'onthisday_page.dart';
import 'scan_page.dart';
import 'stopwatch_page.dart';
import 'timezone_data.dart';

/// 主页面：时钟 + 今天 + 四个功能入口。
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

/// 选中城市存的键；存 IANA 标识而不是城市名——名字可能改，标识不会。
const String _kCityLocation = 'main_city_location';

class _MainPageState extends State<MainPage> {
  CityInfo _city = kDefaultCity;

  /// 今天卡片的数据在 initState 算一次：这些值一天只变一次，
  /// 没必要每次 build 重新拼字符串。
  late final DateTime _today;
  late final DayInfo _info;
  FestivalItem? _nextFestival;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _info = DayInfo.of(_today);
    // 下一个节日节气：节气最长间隔 16 天，这里通常几毫秒就出结果。
    _nextFestival = nextFestivalFrom(_today);
    _loadCity();
  }

  Future<void> _loadCity() async {
    final sp = await SharedPreferences.getInstance();
    final loc = sp.getString(_kCityLocation);
    if (loc == null) return;
    final city = cityByLocation(loc);
    if (mounted) setState(() => _city = city);
  }

  Future<void> _selectCity(CityInfo city) async {
    if (mounted) setState(() => _city = city);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCityLocation, city.location);
  }

  void _openCityPicker() {
    // 泛型用 Object? 而非默认的 void：返回值要做 `is CityInfo` 判断，
    // 对 void 做类型检查是编译错误。
    showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CityPickerSheet(),
    ).then((value) {
      // 底部弹层里选完直接改，这里只负责让卡片刷新。
      if (value is CityInfo) _selectCity(value);
    });
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主页面')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ClockCard(city: _city, onChangeCity: _openCityPicker),
          const SizedBox(height: 12),
          _TodayCard(info: _info, today: _today, next: _nextFestival),
          const SizedBox(height: 12),
          // IntrinsicHeight：让四个按钮等高（第 4 个标签折两行会更高）。
          // 直接在 ListView 里用 stretch 会因交叉轴无界而崩溃，必须先经
          // IntrinsicHeight 把子项高度收敛成有限值再拉伸。
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.document_scanner,
                    label: 'OCR 识别',
                    onTap: () => _push(
                        const ScanPage(initialMode: ScanMode.ocr)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.qr_code_scanner,
                    label: '二维码扫描',
                    onTap: () => _push(
                        const ScanPage(initialMode: ScanMode.barcode)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.timer_outlined,
                    label: '秒表',
                    onTap: () => _push(const StopwatchPage()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.history_edu_outlined,
                    label: '历史上的今天',
                    onTap: () => _push(const OnThisDayPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 时钟
// ---------------------------------------------------------------------------

/// 时钟卡片。做成独立 StatefulWidget 是有意的：只有它需要每秒 setState，
/// 底下的「今天」卡片和按钮跟着每秒重建纯属浪费。
class _ClockCard extends StatefulWidget {
  const _ClockCard({required this.city, required this.onChangeCity});

  final CityInfo city;
  final VoidCallback onChangeCity;

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static const List<String> _week = [
    '一', '二', '三', '四', '五', '六', '日',
  ];

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = nowIn(widget.city);
    final offset = formatUtcOffset(now.timeZoneOffset);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w300,
                // 数字用等宽，否则每秒数字跳动时字宽一变整行都在抖。
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${now.year}年${now.month}月${now.day}日 '
              '星期${_week[now.weekday - 1]}',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onChangeCity,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.public, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      timezonesReady
                          ? '${widget.city.name} · $offset'
                          : '${widget.city.name} · 时区库未就绪',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 今天
// ---------------------------------------------------------------------------

/// 「今天」卡片：公历、农历、干支、生肖、节气，以及最近的节日节气。
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.info,
    required this.today,
    required this.next,
  });

  final DayInfo info;
  final DateTime today;
  final FestivalItem? next;

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  String _distance(int days) {
    if (days == 0) return '就在今天';
    if (days == 1) return '明天';
    return '还有 $days 天';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunar = info.lunar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今天', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row(context, '公历',
                '${today.year}年${today.month}月${today.day}日 ${info.weekText}'),
            _row(context, '农历',
                '${lunar.getYearInChinese()}年'
                '${lunar.getMonthInChinese()}${info.lunarDayText}'),
            _row(context, '干支', info.ganZhiText),
            _row(context, '生肖', lunar.getYearShengXiao()),
            _row(context, '节气', info.jieQiText),
            if (next != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '下一个：${next!.name}',
                            style: theme.textTheme.bodyMedium),
                        if (FestivalPrefs.showEmoji)
                          TextSpan(text: ' ${festivalEmoji(next!)}'),
                      ]),
                    ),
                  ),
                  Text(
                    _distance(next!.daysLeft),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 快捷入口
// ---------------------------------------------------------------------------

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 30, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 城市选择
// ---------------------------------------------------------------------------

/// 城市选择弹层：搜索框 + 分组列表，选中即返回 [CityInfo]。
class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 分组结果展平成混合行：大洲名（String）与首都（CityInfo）交替，
    // 标题行只在该组有命中时出现。
    final rows = <Object>[
      for (final entry in searchCitiesGrouped(_query).entries) ...[
        entry.key,
        ...entry.value,
      ],
    ];
    // 结果太多时把弹层撑高：给了七成屏，剩下的空间让列表自己滚。
    final sheetHeight = MediaQuery.of(context).size.height * 0.7;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索国家或首都，如 日本、巴黎、asia',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text('没有匹配「$_query」的国家或首都',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is String) {
                        // 大洲分组标题：上留白让它和上一组拉开距离。
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            row,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                          ),
                        );
                      }
                      final c = row as CityInfo;
                      return ListTile(
                        dense: true,
                        title: Text(c.name),
                        subtitle: Text('${c.region} · ${c.location}'),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
