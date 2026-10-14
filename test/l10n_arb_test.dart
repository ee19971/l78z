//作者: ee && 3180749809@qq.com
//创建时间: 2026年 10月 13日
//RustRover: l78z
//作用: arb 数据源的一致性——两种语言的 key 集必须完全相同。

//Copyright (c) 2026 by ee19971 3180749809@qq.com, All Rights Reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('en / zh arb 的文案 key 集完全一致', () {
    Map<String, dynamic> read(String name) => jsonDecode(
          File('lib/l10n/app_$name.arb').readAsStringSync(),
        ) as Map<String, dynamic>;

    // `@xxx` 是占位符元数据，不算文案 key。
    Set<String> keys(String name) =>
        read(name).keys.where((k) => !k.startsWith('@')).toSet();

    final zh = keys('zh');
    final en = keys('en');
    expect(zh.difference(en), isEmpty, reason: 'zh 有、en 缺的 key');
    expect(en.difference(zh), isEmpty, reason: 'en 有、zh 缺的 key');
    // 顺手兜个底：迁移做了几百条，不至于一条都没有。
    expect(zh.length, greaterThan(300));
  });
}
