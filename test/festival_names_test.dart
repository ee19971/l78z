//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 15日
//RustRover: l78z
//作用: 节日/节气译名表的完整性——24 节气不缺、lunar 包能吐的名字都有英文。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:l78z/yemian/festival_names.dart';
import 'package:l78z/yemian/festival_scan.dart';
import 'package:lunar/lunar.dart';

void main() {
  test('24 节气全部有英文译名', () {
    const expected = [
      '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
      '立夏', '小满', '芒种', '夏至', '小暑', '大暑',
      '立秋', '处暑', '白露', '秋分', '寒露', '霜降',
      '立冬', '小雪', '大雪', '冬至', '小寒', '大寒',
    ];
    expect(kJieQiEn.keys.toSet(), expected.toSet());
    // 译名非空且不含中文——防手滑把中文抄进英文列。
    for (final e in kJieQiEn.entries) {
      expect(e.value, isNotEmpty, reason: '${e.key} 缺译名');
      expect(RegExp(r'[一-鿿]').hasMatch(e.value), isFalse,
          reason: '${e.key} 的英文译名里混了中文：${e.value}');
    }
  });

  test('lunar 包整年会吐出的名字全部收录（扫 2026 全年）', () {
    final missing = <String>{};
    var day = DateTime(2026, 1, 1);
    while (day.year == 2026) {
      final lunar = Solar.fromYmd(day.year, day.month, day.day).getLunar();
      final names = <String>[
        ...lunar.getFestivals(),
        ...lunar.getOtherFestivals(),
        ...lunar.getSolar().getFestivals(),
        ...lunar.getSolar().getOtherFestivals(),
        if (lunar.getJieQi().isNotEmpty) lunar.getJieQi(),
      ];
      for (final n in names) {
        if (nameEn(n) == n) missing.add(n);
      }
      day = day.add(const Duration(days: 1));
    }
    expect(missing, isEmpty, reason: '这些名字没有英文译名，需补进 kFestivalEn');
  });

  test('未收录的名字回退中文，不会返回空', () {
    expect(nameEn('不存在的节日'), '不存在的节日');
    expect(nameEn('春节'), 'Chinese New Year');
    expect(nameEn('立春'), 'Beginning of Spring');
  });

  test('emoji 查表仍用中文键（译名不影响表情符号）', () {
    // 扫出的节气/节日配了 emoji 的名字，转成英文后 emoji 查表必须还查得到——
    // 这正是「翻译只在展示层做」的契约。
    final items = scanFestivals(days: 60);
    expect(items, isNotEmpty);
    expect(festivalEmoji(items.first), isNotEmpty);
  });
}
