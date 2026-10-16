//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 15日
//RustRover: l78z
//作用: 日历页的显示偏好——格子小字档位与周起始日，纯 UI 设置的读写与缓存。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:shared_preferences/shared_preferences.dart';

/// 格子小字档位。
///
/// `jieqiLunar` 是新默认：节气优先、农历日兜底，不显示任何节日——
/// 节日名在窄格子里既挤占数字空间，又让日历显得嘈杂。
/// `full` 保留旧观感（节日 > 节气 > 农历日），给想看节日的用户切回。
enum CellLabelMode { jieqiLunar, full, lunarOnly, hidden }

/// 日历页的显示偏好。
///
/// 与 [FestivalPrefs] 同一套路：纯 UI 偏好存 SharedPreferences，不走 FRB；
/// 静态内存缓存，设置改完立刻生效，不用等异步读盘。
class CalendarPrefs {
  CalendarPrefs._();

  static const String _kCellLabelMode = 'calendar_cell_label_mode';
  static const String _kWeekStartMonday = 'calendar_week_start_monday';
  static const String _kOtherCalendars = 'calendar_other_calendars';

  /// 「其他历法」区的全部开关键，顺序即设置面板与详情面板的显示顺序。
  /// 前两个由农历换算（lunar 包的 Tao/Foto），后五个由 icu_kit 换算
  /// （见 other_calendars.dart）。
  static const List<String> otherCalendarKeys = [
    'tao',
    'foto',
    'islamic',
    'hebrew',
    'persian',
    'saka',
    'japanese',
  ];

  /// 格子小字档位，默认节气 + 农历日。
  static CellLabelMode cellLabelMode = CellLabelMode.jieqiLunar;

  /// 周起始日是否为周一；默认周日。
  static bool weekStartMonday = false;

  /// 详情面板当前开启的历法键；默认全关，想看再开。
  static Set<String> shownCalendars = {};

  /// [key] 对应的历法行是否显示。
  static bool shows(String key) => shownCalendars.contains(key);

  /// 首屏读一次；脏值一律回落默认（不在 [otherCalendarKeys] 里的直接丢弃）。
  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    cellLabelMode = switch (sp.getString(_kCellLabelMode)) {
      'full' => CellLabelMode.full,
      'lunarOnly' => CellLabelMode.lunarOnly,
      'hidden' => CellLabelMode.hidden,
      _ => CellLabelMode.jieqiLunar,
    };
    weekStartMonday = sp.getBool(_kWeekStartMonday) ?? false;
    shownCalendars = {
      ...?sp.getStringList(_kOtherCalendars)?.where(otherCalendarKeys.contains),
    };
  }

  static Future<void> setCellLabelMode(CellLabelMode mode) async {
    cellLabelMode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kCellLabelMode, mode.name);
  }

  static Future<void> setWeekStartMonday(bool value) async {
    weekStartMonday = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kWeekStartMonday, value);
  }

  /// 开/关某个历法行。
  static Future<void> setShown(String key, bool value) async {
    if (!otherCalendarKeys.contains(key)) return;
    if (value) {
      shownCalendars.add(key);
    } else {
      shownCalendars.remove(key);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kOtherCalendars, shownCalendars.toList());
  }
}
