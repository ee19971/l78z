//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 节日节气的扫描与展示辅助——纯逻辑，不碰 UI，方便单独理清口径。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:math';

import 'package:flutter/material.dart';

import 'festivals.dart';

/// 未来一年里的一条节日或节气记录。
class FestivalItem {
  const FestivalItem({
    required this.name,
    required this.date,
    required this.isJieQi,
    required this.isLunar,
    required this.daysLeft,
  });

  /// 名称，如「重阳节」「霜降」
  final String name;

  /// 公历日期（已归一化到零点）
  final DateTime date;

  /// 是否节气；否则是节日。决定徽章文案与兜底 emoji。
  final bool isJieQi;

  /// 该节日是否属于农历，决定日期行走农历写法还是公历写法。
  ///
  /// 节气是天文节点、公历锚定，恒为 false——图里「霜降」显示的就是
  /// `2026年10月23日 周五`，而农历的「重阳节」显示 `二〇二六年九月初九(10.18) 周日`。
  final bool isLunar;

  /// 距今天数（日历天差），当天为 0。
  final int daysLeft;

  /// 类型徽章文案。
  String get badgeLabel => isJieQi ? '节气' : '节日';
}

/// 扫描从 [from]（默认今天）起 [days] 天内的所有节日和节气。
///
/// 节气和节日分开成条：同一天既有节气又有节日就是两张卡片，与原版一致。
/// 结果按天数升序；同一天内节气排在节日之前——节气是确定性天文节点，
/// 排前面更符合「先看节气再看节日」的阅读习惯。
///
/// 性能：365 次 `Solar + Lunar` 构造约 50~200ms，调用方应先画 loading
/// 再丢进异步，否则首帧会卡。`DayInfo` 自带 400 条缓存，一次扫描正好吃得下。
List<FestivalItem> scanFestivals({DateTime? from, int days = 365}) {
  final base = from ?? DateTime.now();
  final start = DateTime(base.year, base.month, base.day);
  final items = <FestivalItem>[];

  for (var i = 0; i <= days; i++) {
    final date = start.add(Duration(days: i));
    final info = DayInfo.of(date);

    if (info.hasJieQi) {
      items.add(FestivalItem(
        name: info.jieQi,
        date: date,
        isJieQi: true,
        isLunar: false,
        daysLeft: i,
      ));
    }

    for (final name in info.lunarFestivals) {
      items.add(FestivalItem(
        name: name,
        date: date,
        isJieQi: false,
        isLunar: true,
        daysLeft: i,
      ));
    }

    for (final name in info.solarFestivals) {
      items.add(FestivalItem(
        name: name,
        date: date,
        isJieQi: false,
        isLunar: false,
        daysLeft: i,
      ));
    }
  }

  items.sort((a, b) {
    final byDays = a.daysLeft.compareTo(b.daysLeft);
    if (byDays != 0) return byDays;
    // 节气先于节日
    if (a.isJieQi != b.isJieQi) return a.isJieQi ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return items;
}

/// 卡片上的日期行，两种写法对应两种历法：
///
///  - 农历节日：`二〇二六年九月初九(10.18) 周日`
///  - 公历节日与节气：`2026年10月23日 周五`
///
/// 农历那行后面的括号是公历月.日——农历本身不带公历信息，
/// 光看「九月初九」没法排日程，所以补一个括号。
String festivalDateLabel(DayInfo info, bool isLunar) {
  if (!isLunar) {
    final d = info.date;
    return '${d.year}年${d.month}月${d.day}日 ${info.weekShortText}';
  }
  final d = info.date;
  final lunar = info.lunar;
  return '农历${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}'
      '${lunar.getDayInChinese()}(${d.month}.${d.day}) ${info.weekShortText}';
}

/// 从 [from] 起找下一个节日或节气，找到立即返回；40 天内都没有则返回 null。
///
/// 主页面「今天」卡片只要这一条，不值得把整年扫一遍（那要 50~200ms）。
/// 24 节气的最长间隔是 16 天（大寒→立春、处暑→白露），
/// 所以最坏也就扫十几天，通常几毫秒就出结果。
FestivalItem? nextFestivalFrom(DateTime from, {int maxDays = 40}) {
  final start = DateTime(from.year, from.month, from.day);
  for (var i = 0; i <= maxDays; i++) {
    final date = start.add(Duration(days: i));
    final info = DayInfo.of(date);

    if (info.hasJieQi) {
      return FestivalItem(
        name: info.jieQi,
        date: date,
        isJieQi: true,
        isLunar: false,
        daysLeft: i,
      );
    }
    // 节日里农历在前，与 [scanFestivals] 的排序口径保持一致。
    for (final name in info.lunarFestivals) {
      return FestivalItem(
        name: name,
        date: date,
        isJieQi: false,
        isLunar: true,
        daysLeft: i,
      );
    }
    for (final name in info.solarFestivals) {
      return FestivalItem(
        name: name,
        date: date,
        isJieQi: false,
        isLunar: false,
        daysLeft: i,
      );
    }
  }
  return null;
}

/// 查不到时的兜底：节日给彩带，节气给叶子——保证任何一条都不缺图标。
String festivalEmoji(FestivalItem item) {
  if (item.isJieQi) return _jieQiEmoji[item.name] ?? '🌿';
  return _festivalEmoji[item.name] ?? '🎉';
}

/// 24 节气 → emoji。
const Map<String, String> _jieQiEmoji = {
  '立春': '🌱', '雨水': '💧', '惊蛰': '⚡', '春分': '🌸',
  '清明': '🌿', '谷雨': '🌧️', '立夏': '🍃', '小满': '🌾',
  '芒种': '🌾', '夏至': '☀️', '小暑': '🔥', '大暑': '🌡️',
  '立秋': '🍂', '处暑': '🌤️', '白露': '💧', '秋分': '🍁',
  '寒露': '🍂', '霜降': '🍎', '立冬': '❄️', '小雪': '🌨️',
  '大雪': '☃️', '冬至': '🥟', '小寒': '🧊', '大寒': '🥶',
};

/// 常见节日 → emoji。没列到的走 [festivalEmoji] 的兜底 🎉，
/// 常用的都在这张表里了，冷门节日要补的话直接往这里加。
const Map<String, String> _festivalEmoji = {
  // 传统农历
  '春节': '🧧', '过年': '🧧', '除夕': '🎆', '元宵节': '🏮', '元宵': '🏮',
  '灯节': '🏮', '龙抬头': '🐲', '龙头节': '🐲', '端午节': '🛶', '端午': '🛶',
  '七夕': '💘', '七夕节': '💘', '中元节': '🕯️', '中秋节': '🥮', '中秋': '🥮',
  '重阳节': '👴', '重阳': '👴', '腊八节': '🥣', '腊八': '🥣', '小年': '🧹',
  '寒衣节': '🧥', '寒食节': '🌿', '上巳节': '🌿',
  // 公历
  '元旦': '🎆', '情人节': '💘', '妇女节': '👩', '植树节': '🌳',
  '消费者权益日': '🛒', '学雷锋纪念日': '🔱', '劳动节': '💪', '青年节': '🌟',
  '护士节': '💉', '儿童节': '🧒', '建党节': '🎂', '建军节': '🎖️',
  '教师节': '📚', '记者节': '📰', '国庆节': '🇨🇳', '国庆': '🇨🇳',
  '平安夜': '🎅', '圣诞节': '🎄', '圣诞': '🎄', '万圣节': '🎃',
  '万圣节前夜': '👻', '母亲节': '👩', '父亲节': '👨',
  '双十一': '🛍️', '双十二': '🎄', '光棍节': '🤖',
  '全国爱眼日': '👀', '世界读书日': '📚', '世界无烟日': '🚭',
  '世界地球日': '🌏', '世界环境日': '🌍', '世界航天日': '🚀',
  '世界卫生日': '🏥', '世界人口日': '👥', '世界睡眠日': '😴',
  '世界艾滋病日': '❤️', '国际禁毒日': '⚠️', '国家宪法日': '⚖️',
  '消防宣传日': '🧯', '国家公祭日': '🕯️',
  '南京大屠杀死难者国家公祭日': '🕯️', '抗美援朝纪念日': '🎖️',
  '国际减轻自然灾害日': '🌍', '世界发展信息日': '🌐',
};

/// 卡片底色轮换用的粉彩，取自原版截图的八色循环。
///
/// 亮度统一偏高（首字节都是 0xFF，RGB 都在 0xC0 以上），
/// 保证叠上深色文字后对比度达标，不靠透明度去凑。
const List<Color> kFestivalCardColors = [
  Color(0xFFEDE9FE), // 紫
  Color(0xFFDBEAFE), // 蓝
  Color(0xFFFCE7F3), // 粉
  Color(0xFFE0E7FF), // 靛
  Color(0xFFFEF9C3), // 黄
  Color(0xFFFFE4E6), // 玫瑰
  Color(0xFFDCFCE7), // 绿
  Color(0xFFFFEDD5), // 橙
];

/// 取第 [index] 张卡片的底色。
///
/// [random] 为 true 时颜色按 [seed] 打乱后的顺序发牌——同一份列表只要
/// seed 不变，配色就稳定（切页面回来不会整片变色），这也是原版
/// 「封面颜色 → 随机」想要的效果：随机但不闪。
Color festivalCardColor(int index, {required bool random, int seed = 0}) {
  if (!random) {
    return kFestivalCardColors[index % kFestivalCardColors.length];
  }
  final rnd = Random(seed);
  final slots = List<int>.generate(kFestivalCardColors.length, (i) => i)
    ..shuffle(rnd);
  return kFestivalCardColors[slots[index % slots.length]];
}
