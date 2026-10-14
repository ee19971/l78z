//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 「历史上的今天」数据层——维基百科周年纪念日数据的加载与查询。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../l10n/app_localizations.dart';

/// 单条条目：年份 + 描述文本。
class OnThisDayEntry {
  const OnThisDayEntry(this.year, this.text);

  /// 年份。**负数表示公元前**（维基数据原生如此）。
  final int year;

  /// 中文描述。
  final String text;

  /// 年份展示：公元前显示「前221」/「221 BC」，公元直接显示年份数字。
  String yearLabel(AppLocalizations l10n) =>
      year <= 0 ? l10n.onBcLabel(-year) : '$year';
}

/// 某一天的三个分区。
class OnThisDaySection {
  const OnThisDaySection({
    this.events = const [],
    this.births = const [],
    this.deaths = const [],
  });

  /// 大事记。
  final List<OnThisDayEntry> events;

  /// 今日出生。
  final List<OnThisDayEntry> births;

  /// 今日逝世。
  final List<OnThisDayEntry> deaths;

  bool get isEmpty => events.isEmpty && births.isEmpty && deaths.isEmpty;

  /// 条目总数，页头统计用。
  int get total => events.length + births.length + deaths.length;
}

/// 资源文件路径——与 assets 声明保持一致。
const String kOnThisDayAssetPath = 'assets/onthisday/onthisday.json';

/// 日期 → 表键，如 `02-03`、`12-31`。**必须补零**，否则一位数月份查不到。
String onThisDayKey(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 解析整份 JSON（纯函数，测试直接喂字符串即可）。
///
/// 输入形如：
/// ```json
/// {"10-13": {"events":[{"y":2025,"t":"..."}], "births":[...], "deaths":[...]}}
/// ```
Map<String, OnThisDaySection> parseOnThisDayJson(String source) {
  final raw = jsonDecode(source) as Map<String, dynamic>;
  final out = <String, OnThisDaySection>{};
  raw.forEach((key, value) {
    final sec = value as Map<String, dynamic>;
    out[key] = OnThisDaySection(
      events: _entries(sec['events']),
      births: _entries(sec['births']),
      deaths: _entries(sec['deaths']),
    );
  });
  return out;
}

List<OnThisDayEntry> _entries(Object? value) {
  if (value is! List) return const [];
  return [
    for (final e in value)
      if (e is Map)
        OnThisDayEntry(
          (e['y'] as num?)?.toInt() ?? 0,
          e['t'] as String? ?? '',
        ),
  ];
}

/// 解析后的全表缓存：5MB 的 JSON 只解一次，之后所有页面共享。
Map<String, OnThisDaySection>? _cached;

/// 从 assets 加载全表（366 天）。已有缓存时立即返回，不再 IO。
Future<Map<String, OnThisDaySection>> loadOnThisDay() async {
  final hit = _cached;
  if (hit != null) return hit;
  final source = await rootBundle.loadString(kOnThisDayAssetPath);
  final parsed = parseOnThisDayJson(source);
  _cached = parsed;
  return parsed;
}

/// 按日期查表。平年的 02-29 等没有数据的日子返回 null，
/// 调用方负责给空态。
OnThisDaySection? sectionFor(
  Map<String, OnThisDaySection> data,
  DateTime date,
) =>
    data[onThisDayKey(date)];
