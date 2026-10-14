//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: 「历史上的今天」数据层测试——解析、键规范化、查表、真实 assets 冒烟。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/l10n/app_localizations_en.dart';
import 'package:l78z/l10n/app_localizations_zh.dart';
import 'package:l78z/yemian/onthisday.dart';

void main() {
  // rootBundle 需要 ServicesBinding；纯 test() 不像 testWidgets 会自动初始化。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('解析：三段结构与负年份（公元前）', () {
    final data = parseOnThisDayJson(jsonEncode({
      '10-13': {
        'events': [
          {'y': 2025, 't': '大事一'},
          {'y': -221, 't': '公元前的大事'},
        ],
        'births': [
          {'y': 1923, 't': '某人生于这一天'},
        ],
        'deaths': [],
      },
    }));
    expect(data.keys, ['10-13']);
    final sec = data['10-13']!;
    expect(sec.events.length, 2);
    expect(sec.events[0].year, 2025);
    expect(sec.events[1].year, -221);
    expect(sec.births.single.year, 1923);
    expect(sec.deaths, isEmpty);
    expect(sec.total, 3);
    expect(sec.isEmpty, isFalse);
  });

  test('解析：单元素数组保持数组形态，缺失段容错为空', () {
    // 真实数据里某些日子 deaths 只有一条甚至没有，
    // 解析端必须对单元素 List 与 null 段都安全。
    final data = parseOnThisDayJson(jsonEncode({
      '01-01': {
        'events': [
          {'y': 1, 't': '唯一一条'},
        ],
        // births 故意缺失，deaths 显式 null
        'deaths': null,
      },
    }));
    final sec = data['01-01']!;
    expect(sec.events, hasLength(1));
    expect(sec.births, isEmpty);
    expect(sec.deaths, isEmpty);
    expect(sec.isEmpty, isFalse);
  });

  test('解析：脏数据条目字段缺失时安全降级', () {
    final data = parseOnThisDayJson(jsonEncode({
      '03-05': {
        'events': [
          {}, // 无 y 无 t
          {'y': null, 't': '有文无年'},
          {'y': 2000}, // 有年无文
        ],
      },
    }));
    final sec = data['03-05']!;
    expect(sec.events.length, 3);
    expect(sec.events[0].year, 0);
    expect(sec.events[0].text, '');
    expect(sec.events[1].text, '有文无年');
    expect(sec.events[2].year, 2000);
  });

  test('键：月日必须补零', () {
    expect(onThisDayKey(DateTime(2026, 2, 3)), '02-03');
    expect(onThisDayKey(DateTime(2026, 12, 31)), '12-31');
    expect(onThisDayKey(DateTime(2026, 10, 13)), '10-13');
  });

  test('年份展示：公元前带「前」字 / BC', () {
    final zh = AppLocalizationsZh();
    final en = AppLocalizationsEn();
    expect(const OnThisDayEntry(2025, '').yearLabel(zh), '2025');
    expect(const OnThisDayEntry(-221, '').yearLabel(zh), '前221');
    expect(const OnThisDayEntry(-221, '').yearLabel(en), '221 BC');
  });

  test('查表：命中返回分区，缺日期返回 null', () {
    final data = parseOnThisDayJson(jsonEncode({
      '02-29': {
        'events': [
          {'y': 2024, 't': '闰日大事'},
        ],
      },
    }));
    expect(sectionFor(data, DateTime(2024, 2, 29)), isNotNull);
    // 平年 2/29 在表里（下载按闰年遍历），但 1 月 2 日这种没数据的日子要返回 null
    expect(sectionFor(data, DateTime(2026, 1, 2)), isNull);
  });

  test('空分区：isEmpty 与统计口径', () {
    const empty = OnThisDaySection();
    expect(empty.isEmpty, isTrue);
    expect(empty.total, 0);
  });

  group('真实数据冒烟（assets/onthisday/onthisday.json）', () {
    test('全表 366 天且首尾日期齐全', () async {
      final data = await loadOnThisDay();
      expect(data.length, 366, reason: '应覆盖全年 366 天（含 02-29）');
      expect(data.containsKey('01-01'), isTrue);
      expect(data.containsKey('12-31'), isTrue);
      expect(data.containsKey('02-29'), isTrue);
    });

    test('抽验 10-13：三段都有数据且年份合理', () async {
      final data = await loadOnThisDay();
      final sec = sectionFor(data, DateTime(2026, 10, 13));
      expect(sec, isNotNull);
      expect(sec!.events.length, greaterThan(10));
      expect(sec.births, isNotEmpty);
      expect(sec.deaths, isNotEmpty);
      // 大事记应以近代年份为主，最早一条不早于公元前 1000 年
      final minYear = sec.events.map((e) => e.year).reduce((a, b) => a < b ? a : b);
      expect(minYear, greaterThan(-1000));
    });

    test('加载两次共享缓存（同一实例）', () async {
      final a = await loadOnThisDay();
      final b = await loadOnThisDay();
      expect(identical(a, b), isTrue);
    });
  });
}
