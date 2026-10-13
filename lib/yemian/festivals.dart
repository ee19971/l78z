import 'package:lunar/lunar.dart';

/// 单日历法信息：节日、节气、干支、农历等。
///
/// 月视图里同一个日期会被网格单元和底部详情栏各取一次，
/// [DayInfo.of] 按「年月日」缓存，保证每天只计算一次 Lunar。
class DayInfo {
  DayInfo._({
    required this.date,
    required this.solar,
    required this.lunar,
    required this.festivals,
    required this.lunarFestivals,
    required this.solarFestivals,
    required this.jieQi,
    required this.yearGanZhi,
    required this.monthGanZhi,
    required this.dayGanZhi,
  });

  /// 取某一天的历法信息（带缓存）
  factory DayInfo.of(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final key = day.year * 10000 + day.month * 100 + day.day;

    final cached = _cache[key];
    if (cached != null) return cached;

    final solar = Solar.fromDate(day);
    final lunar = solar.getLunar();
    final info = DayInfo._(
      date: day,
      solar: solar,
      lunar: lunar,
      festivals: List<String>.unmodifiable(<String>[
        ...lunar.getFestivals(),
        ...solar.getFestivals(),
        ...solar.getOtherFestivals(),
        ...lunar.getOtherFestivals(),
      ]),
      // 来源分开放：节日节气页要按来源选日期写法——农历节日显示
      // 「二〇二六年九月初九(10.18)」，公历节日和节气显示「2026年10月23日」。
      // 上面合并后的 festivals 只留了名字，来源已经丢了。
      lunarFestivals: List<String>.unmodifiable(<String>[
        ...lunar.getFestivals(),
        ...lunar.getOtherFestivals(),
      ]),
      solarFestivals: List<String>.unmodifiable(<String>[
        ...solar.getFestivals(),
        ...solar.getOtherFestivals(),
      ]),
      jieQi: lunar.getJieQi(),
      yearGanZhi: lunar.getYearInGanZhi(),
      monthGanZhi: lunar.getMonthInGanZhi(),
      dayGanZhi: lunar.getDayInGanZhi(),
    );

    if (_cache.length >= _maxCacheSize) _cache.clear();
    _cache[key] = info;
    return info;
  }

  static const int _maxCacheSize = 400;
  static final Map<int, DayInfo> _cache = <int, DayInfo>{};

  /// 归一化后的日期（年月日）
  final DateTime date;
  final Solar solar;
  final Lunar lunar;

  /// 当天所有节日：农历节日 + 公历节日 + 其它节日
  ///
  /// 顺序保持为「农历 → 公历 → 其它」，日历页的 [cellLabel] 取首元素，
  /// 顺序变会导致网格小字换词。
  final List<String> festivals;

  /// 只来自农历的节日（含「其它」里的农历部分），日期行走农历写法时用。
  final List<String> lunarFestivals;

  /// 只来自公历的节日（含「其它」里的公历部分），日期行走公历写法时用。
  final List<String> solarFestivals;

  /// 节气名，非节气日为空字符串
  final String jieQi;

  final String yearGanZhi;
  final String monthGanZhi;
  final String dayGanZhi;

  bool get hasFestival => festivals.isNotEmpty;
  bool get hasJieQi => jieQi.isNotEmpty;

  /// 节日列表文本
  String get festivalText => festivals.isEmpty ? '无' : festivals.join('、');

  /// 节气文本
  String get jieQiText => jieQi.isEmpty ? '无' : jieQi;

  /// 干支：如 `丙午年 丁酉月 甲子日`
  String get ganZhiText => '$yearGanZhi年 $monthGanZhi月 $dayGanZhi日';

  /// 农历日文本，如 `初一`
  String get lunarDayText => lunar.getDayInChinese();

  /// 星期文本，如 `星期六`
  String get weekText => '星期${lunar.getWeekInChinese()}';

  /// 短星期，如 `周六`——节日节气页的日期行和图里一致用短写法。
  String get weekShortText => '周${lunar.getWeekInChinese()}';

  /// 网格小字：节日 > 节气 > 农历日
  String get cellLabel {
    if (hasFestival) return festivals.first;
    if (hasJieQi) return jieQi;
    return lunarDayText;
  }

  /// 释放缓存（切换账号、离开页面等场景可调用）
  static void clearCache() => _cache.clear();
}
