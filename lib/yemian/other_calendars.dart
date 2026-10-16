//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 16日
//RustRover: l78z
//作用: 其他历法（伊斯兰/希伯来/波斯/印度 Saka/日本年号）的换算与显示，
//      引擎是 icu_kit（Unicode 官方 ICU4X，FFI）。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:icu_kit/icu_kit.dart';

/// icu_kit 引擎是否初始化成功。
///
/// main() 启动时尝试 `IcuKit.init()`；失败（如预编译二进制缺失、
/// 数据加载出错）只禁用这几个历法行，应用其余功能照常。
/// 测试环境不跑 main()，保持 false，走「引擎不可用」的防御分支。
bool icuKitReady = false;

/// 五个 ICU 历法在 CalendarPrefs 里的键 → ICU 历法类型。
///
/// 道历/佛历不在这里——它们由 lunar 包从农历直接换算（calendar.dart）。
const Map<String, IcuCalendarKind> kIcuCalendarKeys = {
  'islamic': IcuCalendarKind.hijriUmmAlQura,
  'hebrew': IcuCalendarKind.hebrew,
  'persian': IcuCalendarKind.persian,
  'saka': IcuCalendarKind.indian,
  'japanese': IcuCalendarKind.japanese,
};

/// 每个 kind 一个常驻实例：工厂每次新建都要过一遍 FFI 分发，缓存掉。
final Map<IcuCalendarKind, IcuCalendar> _instances = {};

/// 日本年号译名：ICU 的 era code 是罗马字小写（如 "reiwa"）。
/// 表里没有的古代年号直接用原文兜底，不值得为冷门年号膨胀这张表。
const Map<String, String> _japaneseEraZh = {
  'reiwa': '令和',
  'heisei': '平成',
  'showa': '昭和',
  'taisho': '大正',
  'meiji': '明治',
  'taisei': '大政',
  'keio': '庆应',
  'manen': '万延',
  'bunkyu': '文久',
  'genji': '元治',
  'koka': '弘化',
  'kaei': '嘉永',
  'ansei': '安政',
};

/// 把公历 [date] 换算成 [key] 历法的一行文本（如 `1445年1月1日`、
/// `令和8年10月18日`）。
///
/// 一律走「公历 → IcuCalendarDate → 手动拼年月日」：ICU 的
/// `DateFormat.format(DateTime)` 要处理「这个 DateTime 按哪个时区解释」
/// 的歧义，纯日期字段没有这个问题，显示口径也与道历/佛历行一致。
///
/// 任何异常（引擎没就绪、历法数据缺失、键不认识）都返回 null——
/// 调用方按「该行不显示」处理，绝不让详情面板崩掉。
String? icuCalendarText(String key, DateTime date) {
  if (!icuKitReady) return null;
  final kind = kIcuCalendarKeys[key];
  if (kind == null) return null;
  try {
    final d = IcuCalendarDate.fromGregorian(
      year: date.year,
      month: date.month,
      day: date.day,
      calendar: _instances.putIfAbsent(kind, () => IcuCalendar(kind)),
    );
    final year = key == 'japanese'
        // 日本历显示「令和8年」：年号在 era 字段，数字是 era 内年份。
        ? '${_japaneseEraZh[d.era] ?? d.era}${d.eraYearOrRelatedIso}'
        : '${d.extendedYear}';
    return '$year年${d.monthNumber}月${d.dayOfMonth}日';
  } catch (e) {
    debugPrint('其他历法换算失败 $key $date: $e');
    return null;
  }
}
