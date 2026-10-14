//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 主页面——可切换城市的时钟、今天历法信息、功能快捷入口。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import 'app_settings.dart';
import 'city_picker.dart';
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

/// 选中城市的键在 [AppSettingsModel] 侧（kCityLocation），
/// 设置页与时钟共用同一份，这里只是引用。

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
    final loc = sp.getString(kCityLocation);
    if (loc == null) return;
    final city = cityByLocation(loc);
    if (mounted) setState(() => _city = city);
  }

  Future<void> _selectCity(CityInfo city) async {
    if (mounted) setState(() => _city = city);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(kCityLocation, city.location);
  }

  void _openCityPicker() async {
    final city = await showCityPickerSheet(context);
    // 弹层选完直接改，这里只负责让卡片刷新。
    if (city != null && mounted) _selectCity(city);
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainTitle)),
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
                    label: l10n.mainOcr,
                    onTap: () => _push(
                        const ScanPage(initialMode: ScanMode.ocr)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.qr_code_scanner,
                    label: l10n.mainQrScan,
                    onTap: () => _push(
                        const ScanPage(initialMode: ScanMode.barcode)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.timer_outlined,
                    label: l10n.mainStopwatch,
                    onTap: () => _push(const StopwatchPage()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.history_edu_outlined,
                    label: l10n.mainOnThisDay,
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

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final loc = Localizations.localeOf(context).toString();
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
              // 日期与星期交给 intl 按 locale 格式化：
              // 中文「2026年10月13日 星期二」，英文「Oct 13, 2026 Tuesday」。
              '${DateFormat.yMMMd(loc).format(now)} '
              '${DateFormat.EEEE(loc).format(now)}',
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
                          : '${widget.city.name} · ${l10n.mainTzNotReady}',
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

  String _distance(AppLocalizations l10n, int days) {
    if (days == 0) return l10n.mainToday;
    if (days == 1) return l10n.mainTomorrow;
    return l10n.mainInDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final loc = Localizations.localeOf(context).toString();
    final lunar = info.lunar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mainTodayTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row(
                context,
                l10n.mainSolar,
                '${DateFormat.yMMMd(loc).format(today)} '
                '${DateFormat.EEEE(loc).format(today)}'),
            // 农历/干支/生肖/节气是中华文化数据本身，保持中文原样，
            // 只有标签跟随界面语言。
            _row(context, l10n.mainLunar,
                '${lunar.getYearInChinese()}年'
                '${lunar.getMonthInChinese()}${info.lunarDayText}'),
            _row(context, l10n.mainGanZhi, info.ganZhiText),
            _row(context, l10n.mainZodiac, lunar.getYearShengXiao()),
            _row(context, l10n.mainJieQi, info.jieQiText),
            if (next != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: l10n.mainNextFestival(next!.name),
                            style: theme.textTheme.bodyMedium),
                        if (FestivalPrefs.showEmoji)
                          TextSpan(text: ' ${festivalEmoji(next!)}'),
                      ]),
                    ),
                  ),
                  Text(
                    _distance(l10n, next!.daysLeft),
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
