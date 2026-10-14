//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 「历史上的今天」页面——大事记 / 今天出生 / 今天逝世 三个分区，
//      数据来自内置的维基百科周年纪念日表（assets/onthisday/onthisday.json）。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'onthisday.dart';

/// 历史上的今天页面。
///
/// [date] 为空时取今天；测试与调试可传任意日期。
class OnThisDayPage extends StatefulWidget {
  const OnThisDayPage({super.key, this.date});

  /// 目标日期。null = `DateTime.now()`。
  final DateTime? date;

  @override
  State<OnThisDayPage> createState() => _OnThisDayPageState();
}

class _OnThisDayPageState extends State<OnThisDayPage> {
  late final DateTime _date = widget.date ?? DateTime.now();

  /// 全表只解一次，之后所有页面共享（见 loadOnThisDay 的静态缓存）。
  late final Future<Map<String, OnThisDaySection>> _future = loadOnThisDay();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mainOnThisDay)),
      body: FutureBuilder<Map<String, OnThisDaySection>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.otdLoadFailed('${snap.error}'),
                    textAlign: TextAlign.center),
              ),
            );
          }
          final section = sectionFor(snap.data!, _date);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeaderCard(date: _date, section: section),
              ..._group(
                title: l10n.otdEvents,
                icon: Icons.history_edu_outlined,
                color: const Color(0xFF6366F1), // 靛蓝
                entries: section?.events ?? const [],
              ),
              ..._group(
                title: l10n.otdBirths,
                icon: Icons.cake_outlined,
                color: const Color(0xFFDB2777), // 玫红
                entries: section?.births ?? const [],
              ),
              ..._group(
                title: l10n.otdDeaths,
                icon: Icons.star_border,
                color: const Color(0xFF64748B), // 灰蓝（肃穆）
                entries: section?.deaths ?? const [],
              ),
              if (section == null || section.isEmpty)
                _EmptyCard(text: l10n.otdEmpty),
            ],
          );
        },
      ),
    );
  }

  /// 生成一个分区卡片（无条目时返回空列表，即整段隐藏）。
  List<Widget> _group({
    required String title,
    required IconData icon,
    required Color color,
    required List<OnThisDayEntry> entries,
  }) {
    if (entries.isEmpty) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      Card(
        margin: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.of(context)!.otdCount(entries.length),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _EntryRow(
                      entry: entries[i],
                      color: color,
                      // 末条不画分隔线
                      divider: i < entries.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// 页头：日期大字 + 三个分区的条目统计。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.date, required this.section});

  final DateTime date;
  final OnThisDaySection? section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final loc = Localizations.localeOf(context).toString();
    final events = section?.events.length ?? 0;
    final births = section?.births.length ?? 0;
    final deaths = section?.deaths.length ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // 月日 + 星期交给 intl 按 locale 格式化。
              '${DateFormat.MMMd(loc).format(date)} '
              '${DateFormat.EEEE(loc).format(date)}',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              section == null || section!.isEmpty
                  ? l10n.otdNoData
                  : l10n.otdSummary(events, births, deaths),
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条：年份徽章 + 描述文本。
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.color, required this.divider});

  final OnThisDayEntry entry;
  final Color color;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: divider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 年份：公元前显示「前221」，等宽数字防跳动
          SizedBox(
            width: 52,
            child: Text(
              entry.yearLabel(AppLocalizations.of(context)!),
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(entry.text, style: text.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 空态卡片（如平年的 02-29）。
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
