//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 节日节气页的显示偏好——纯 UI 设置的读写与缓存。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:shared_preferences/shared_preferences.dart';

/// 节日节气页的显示偏好。
///
/// 存 SharedPreferences 而不走 FRB：这些是纯 UI 偏好（表情开关、卡片配色、
/// 隐藏了哪些节日），Rust 侧一个都用不到，走一遍 codegen 只是多生成一个
/// 没人读的 JSON 文件。提醒功能已经明确不做，将来也不会有原生侧需要读它。
///
/// 三个页面（列表 / 设置 / 隐藏管理）共用同一份静态状态：设置页改完直接
/// 更新这里并落盘，列表页 pop 回来读到的就是新值，不必再走一次异步读盘。
class FestivalPrefs {
  FestivalPrefs._();

  static const String _kShowEmoji = 'festival_show_emoji';
  static const String _kShowCover = 'festival_show_cover';
  static const String _kCoverColor = 'festival_cover_color';
  static const String _kHidden = 'festival_hidden';

  /// 卡片上是否显示 emoji。
  static bool showEmoji = true;

  /// 卡片上是否上彩色背景；关掉就是白卡片。
  static bool showCover = true;

  /// 配色模式：`order` 按顺序轮换，`random` 按当日 seed 发牌。
  static String coverColor = 'order';

  /// 被隐藏的节日 / 节气名，列表页据此过滤，隐藏管理页据此分组。
  static final Set<String> hidden = <String>{};

  /// 配色是否随机。
  static bool get randomCover => coverColor == 'random';

  /// 首屏读一次。之后靠下面几个 setter 同步内存与磁盘。
  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    showEmoji = sp.getBool(_kShowEmoji) ?? true;
    showCover = sp.getBool(_kShowCover) ?? true;
    coverColor = sp.getString(_kCoverColor) ?? 'order';
    hidden
      ..clear()
      ..addAll(sp.getStringList(_kHidden) ?? const <String>[]);
  }

  static Future<void> setShowEmoji(bool v) async {
    showEmoji = v;
    await _save();
  }

  static Future<void> setShowCover(bool v) async {
    showCover = v;
    await _save();
  }

  static Future<void> setCoverColor(String v) async {
    coverColor = v;
    await _save();
  }

  /// [name] 在 [hide] 为 true 时加入隐藏名单，否则移出。
  static Future<void> setHidden(String name, bool hide) async {
    if (hide) {
      hidden.add(name);
    } else {
      hidden.remove(name);
    }
    await _save();
  }

  static Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kShowEmoji, showEmoji);
    await sp.setBool(_kShowCover, showCover);
    await sp.setString(_kCoverColor, coverColor);
    await sp.setStringList(_kHidden, hidden.toList(growable: false));
  }
}
