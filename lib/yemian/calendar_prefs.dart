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
  static const String _kShowTao = 'calendar_show_tao';
  static const String _kShowFoto = 'calendar_show_foto';

  /// 格子小字档位，默认节气 + 农历日。
  static CellLabelMode cellLabelMode = CellLabelMode.jieqiLunar;

  /// 周起始日是否为周一；默认周日。
  static bool weekStartMonday = false;

  /// 详情面板是否显示道历行；默认关，想看再开。
  static bool showTao = false;

  /// 详情面板是否显示佛历行；默认关。
  static bool showFoto = false;

  /// 首屏读一次；脏值一律回落默认。
  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    cellLabelMode = switch (sp.getString(_kCellLabelMode)) {
      'full' => CellLabelMode.full,
      'lunarOnly' => CellLabelMode.lunarOnly,
      'hidden' => CellLabelMode.hidden,
      _ => CellLabelMode.jieqiLunar,
    };
    weekStartMonday = sp.getBool(_kWeekStartMonday) ?? false;
    showTao = sp.getBool(_kShowTao) ?? false;
    showFoto = sp.getBool(_kShowFoto) ?? false;
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

  static Future<void> setShowTao(bool value) async {
    showTao = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowTao, value);
  }

  static Future<void> setShowFoto(bool value) async {
    showFoto = value;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowFoto, value);
  }
}
